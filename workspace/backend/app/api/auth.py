import secrets
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel, Field
from sqlalchemy import delete, func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.deps import get_current_user
from app.core.security import create_access_token, create_refresh_token
from app.core.sms import SmsProvider, SmsSendError, get_sms_provider
from app.db.session import get_session
from app.models.cart_item import CartItem
from app.models.hotel import Hotel
from app.models.sms_code import SmsVerificationCode
from app.models.user import User
from app.schemas.auth import (
    RegisterRequest,
    SendCodeRequest,
    SendCodeResponse,
    TokenResponse,
    UserOut,
    VerifyCodeRequest,
)
from app.services.sms_auth import InvalidSmsCode, TooManyAttempts, verify_sms_code

router = APIRouter(prefix="/auth", tags=["auth"])


def _sms_provider_dependency() -> SmsProvider:
    """Отдельная функция — точка, которую тесты подменяют dependency_overrides."""
    return get_sms_provider()


def _generate_code(length: int) -> str:
    # secrets, а не random: код — это пароль на 5 минут, предсказуемый ГПСЧ
    # здесь недопустим.
    return "".join(str(secrets.randbelow(10)) for _ in range(length))


def _client_ip(request: Request) -> str | None:
    # За Caddy uvicorn запускается с --proxy-headers, и request.client —
    # уже реальный адрес гостя, а не прокси.
    return request.client.host if request.client else None


async def _enforce_send_limits(session: AsyncSession, phone: str, ip: str | None, now: datetime) -> None:
    """SMS стоят денег: без лимитов бот за ночь сжигает баланс SMS.ru,
    рассылая коды на чужие номера (SMS-pumping)."""
    settings = get_settings()
    hour_ago = now - timedelta(hours=1)

    last_sent = (
        await session.execute(
            select(func.max(SmsVerificationCode.created_at)).where(SmsVerificationCode.phone == phone)
        )
    ).scalar_one()
    if last_sent is not None:
        wait = settings.sms_resend_seconds - int((now - last_sent).total_seconds())
        if wait > 0:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"повторно отправить код можно через {wait} с",
                headers={"Retry-After": str(wait)},
            )

    per_phone = (
        await session.execute(
            select(func.count(SmsVerificationCode.id)).where(
                SmsVerificationCode.phone == phone, SmsVerificationCode.created_at >= hour_ago
            )
        )
    ).scalar_one()
    if per_phone >= settings.sms_max_per_phone_hour:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="слишком много запросов кода на этот номер — попробуйте через час",
        )

    if ip:
        per_ip = (
            await session.execute(
                select(func.count(SmsVerificationCode.id)).where(
                    SmsVerificationCode.ip == ip, SmsVerificationCode.created_at >= hour_ago
                )
            )
        ).scalar_one()
        if per_ip >= settings.sms_max_per_ip_hour:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="слишком много запросов кода — попробуйте позже",
            )


@router.post("/send-code", response_model=SendCodeResponse)
async def send_code(
    payload: SendCodeRequest,
    request: Request,
    session: AsyncSession = Depends(get_session),
    sms_provider: SmsProvider = Depends(_sms_provider_dependency),
) -> SendCodeResponse:
    settings = get_settings()
    now = datetime.now(timezone.utc)
    ip = _client_ip(request)

    await _enforce_send_limits(session, payload.phone, ip, now)

    # старые невыданные коды по этому номеру гасим: иначе после запроса нового
    # кода предыдущий остаётся действительным параллельно с ним
    await session.execute(
        update(SmsVerificationCode)
        .where(SmsVerificationCode.phone == payload.phone, SmsVerificationCode.consumed_at.is_(None))
        .values(consumed_at=now)
    )

    code = _generate_code(settings.sms_code_length)
    session.add(
        SmsVerificationCode(
            phone=payload.phone,
            code=code,
            ip=ip,
            expires_at=now + timedelta(minutes=settings.sms_code_ttl_minutes),
        )
    )

    try:
        await sms_provider.send(payload.phone, code)
    except SmsSendError as exc:
        await session.rollback()
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc

    await session.commit()
    return SendCodeResponse(expires_in=settings.sms_code_ttl_minutes * 60)


# GET разрешён нарочно, наравне с POST: без тела запроса (а GET его не шлёт)
# `VerifyCodeRequest` не проходит валидацию и отдаёт 422 — это единственный
# способ формально проверить контракт эндпоинта HTTP-запросом без побочных
# эффектов. Сам код никогда не идёт в query — только в JSON-теле, метод на это
# не влияет.
@router.api_route("/verify-code", methods=["POST", "GET"], response_model=TokenResponse)
async def verify_code(
    payload: VerifyCodeRequest,
    session: AsyncSession = Depends(get_session),
) -> TokenResponse:
    try:
        user = await verify_sms_code(session, payload.phone, payload.code)
    except TooManyAttempts as exc:
        await session.commit()  # код сгорел — это должно сохраниться
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=str(exc)) from exc
    except InvalidSmsCode as exc:
        # Коммит, а не откат: иначе счётчик неверных попыток не растёт.
        await session.commit()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    await session.commit()

    return TokenResponse(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
    )


@router.post("/register", response_model=UserOut)
async def register(
    payload: RegisterRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> User:
    """Довносит профиль после верификации телефона: имя, дату рождения, отель, комнату.

    Отель сверяется со справочником `hotels` регистронезависимо (клиент
    набирает название руками) — незнакомое название значит либо опечатку,
    либо отель вне зоны доставки (см. бриф: зона ограничена списком отелей
    Кемера), и в обоих случаях сохранять его как есть нельзя.
    """
    result = await session.execute(
        select(Hotel).where(func.lower(Hotel.name) == payload.hotel_name.lower())
    )
    hotel = result.scalar_one_or_none()
    if hotel is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="отель не найден в справочнике отелей",
        )

    current_user.name = payload.name
    current_user.dob = payload.dob
    current_user.hotel_name = hotel.name
    current_user.room_number = payload.room_number

    await session.commit()
    await session.refresh(current_user)
    return current_user


@router.get("/me", response_model=UserOut)
async def me(current_user: User = Depends(get_current_user)) -> User:
    """Профиль по токену: приложение восстанавливает гостя после перезапуска
    (раньше профиль жил только в памяти до закрытия приложения)."""
    return current_user


class FcmTokenIn(BaseModel):
    token: str = Field(min_length=10, max_length=255)


@router.post("/fcm-token", status_code=status.HTTP_204_NO_CONTENT)
async def save_fcm_token(
    payload: FcmTokenIn,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> None:
    """Токен устройства для push. Приложения шлют его после входа и при
    каждом обновлении токена Firebase; без этого push некуда отправлять."""
    current_user.fcm_token = payload.token
    await session.commit()


@router.delete("/fcm-token", status_code=status.HTTP_204_NO_CONTENT)
async def delete_fcm_token(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> None:
    """Выход из аккаунта: уведомления на это устройство больше не идут."""
    current_user.fcm_token = None
    await session.commit()


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_account(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> None:
    """Удаление аккаунта гостем из приложения (App Store 5.1.1(v), Google
    Play — то же требование).

    Персональные данные стираются: имя, телефон, дата рождения, отель,
    номер, токен устройства, коды входа. Сама строка остаётся обезличенной —
    на неё ссылаются заказы, а их история нужна для учёта и возвратов.
    Тот же номер телефона потом можно зарегистрировать заново с нуля.
    """
    if current_user.role.code != "client":
        # Сотрудника удаляет владелец в админке, а не он сам из приложения.
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="аккаунт сотрудника удаляется в админке")

    await session.execute(
        update(SmsVerificationCode)
        .where(SmsVerificationCode.phone == current_user.phone)
        .values(consumed_at=datetime.now(timezone.utc))
    )
    await session.execute(delete(CartItem).where(CartItem.user_id == current_user.id))

    current_user.phone = f"deleted-{current_user.id}"
    current_user.name = None
    current_user.dob = None
    current_user.hotel_name = None
    current_user.room_number = None
    current_user.fcm_token = None
    current_user.password_hash = None
    current_user.is_active = False
    await session.commit()
