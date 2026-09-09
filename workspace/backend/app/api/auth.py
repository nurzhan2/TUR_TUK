import random
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.deps import get_current_user
from app.core.security import create_access_token, create_refresh_token
from app.core.sms import SmsProvider, SmsSendError, get_sms_provider
from app.db.session import get_session
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
from app.services.sms_auth import InvalidSmsCode, verify_sms_code

router = APIRouter(prefix="/auth", tags=["auth"])


def _sms_provider_dependency() -> SmsProvider:
    """Отдельная функция — точка, которую тесты подменяют dependency_overrides."""
    return get_sms_provider()


def _generate_code(length: int) -> str:
    return "".join(str(random.randint(0, 9)) for _ in range(length))


@router.post("/send-code", response_model=SendCodeResponse)
async def send_code(
    payload: SendCodeRequest,
    session: AsyncSession = Depends(get_session),
    sms_provider: SmsProvider = Depends(_sms_provider_dependency),
) -> SendCodeResponse:
    settings = get_settings()
    now = datetime.now(timezone.utc)

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
    except InvalidSmsCode as exc:
        await session.rollback()
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
