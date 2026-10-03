"""Интеграция ЮKassa: создание платежа с редиректом на её хостед-страницу
оплаты и приём вебхука о результате.

`POST /payments/create` создаёт платёж в ЮKassa и возвращает
`confirmation_url`, куда мобильное приложение редиректит клиента — сама
ЮKassa сразу открывает способ, выбранный гостем в приложении (карта/СБП,
`order.payment_method`); наличных нет (см. `app/core/yookassa.py`).

`POST /payments/webhook` — публичный эндпоинт без авторизации (ЮKassa шлёт
его без заголовков нашей аутентификации), поэтому статусу из тела запроса
не доверяем: он только называет ID платежа, а фактический статус
перезапрашивается через `GET /payments/{id}` с нашим секретом.
"""

from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.core.config import get_settings
from app.core.yookassa import YookassaClient, YookassaError, get_yookassa_client
from app.db.session import get_session
from app.models.order import Order, OrderPaymentStatus, OrderStatus
from app.models.payment import Payment, PaymentMethod, PaymentStatus
from app.models.user import User
from app.schemas.payment import PaymentCreateRequest, PaymentCreateResponse, PaymentWebhookRequest

router = APIRouter(prefix="/payments", tags=["payments"])

# Прямое отображение статусов ЮKassa на наши — значения из документации API
# (pending/waiting_for_capture/succeeded/canceled). waiting_for_capture не
# встретится при capture=true (см. create_payment), но на всякий случай не
# считается ни успехом, ни отменой — остаётся PENDING.
_YOOKASSA_STATUS_MAP: dict[str, PaymentStatus] = {
    "pending": PaymentStatus.PENDING,
    "waiting_for_capture": PaymentStatus.PENDING,
    "succeeded": PaymentStatus.SUCCEEDED,
    "canceled": PaymentStatus.CANCELED,
}


def _yookassa_client_dependency() -> YookassaClient:
    """Отдельная функция — точка, которую тесты подменяют через
    `app.dependency_overrides` (тот же приём, что `_sms_provider_dependency`
    в `app/api/auth.py`).

    Отсутствие credentials ловится здесь же, а не внутри хендлера: исключение
    из `Depends(...)` FastAPI поднимает ДО тела эндпоинта, и там `try/except
    YookassaError` вокруг `yookassa.create_payment(...)` его бы не увидел —
    клиент получил бы голый 500 вместо внятного 502."""
    try:
        return get_yookassa_client()
    except YookassaError as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc


@router.post("/create", response_model=PaymentCreateResponse, status_code=status.HTTP_201_CREATED)
async def create_payment(
    payload: PaymentCreateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
    yookassa: YookassaClient = Depends(_yookassa_client_dependency),
) -> Payment:
    order = (
        await session.execute(select(Order).where(Order.id == payload.order_id))
    ).scalar_one_or_none()
    if order is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="заказ не найден")
    if order.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="нельзя оплатить чужой заказ"
        )
    if order.payment_status == OrderPaymentStatus.PAID:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="заказ уже оплачен")
    if order.status == OrderStatus.CANCELLED:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="заказ отменён")

    # Гость нажал «Оплатить» дважды или вернулся со страницы оплаты, не
    # заплатив: свежий неоплаченный платёж отдаём снова, а не плодим второй
    # (иначе можно дважды списать деньги за один заказ).
    fresh_since = datetime.now(timezone.utc) - timedelta(minutes=30)
    existing = (
        await session.execute(
            select(Payment)
            .where(
                Payment.order_id == order.id,
                Payment.status == PaymentStatus.PENDING,
                Payment.created_at >= fresh_since,
            )
            .order_by(Payment.id.desc())
            .limit(1)
        )
    ).scalar_one_or_none()
    if existing is not None and float(existing.amount) == float(order.total):
        return existing

    attempts = (
        await session.execute(select(func.count(Payment.id)).where(Payment.order_id == order.id))
    ).scalar_one()

    settings = get_settings()
    try:
        response = await yookassa.create_payment(
            amount=float(order.total),
            currency="RUB",
            description=f"Заказ №{order.id}",
            return_url=settings.yookassa_return_url,
            order_id=order.id,
            payment_method=order.payment_method,
            # Стабильный ключ попытки: сетевой ретрай того же запроса вернёт
            # тот же платёж, а не создаст второй.
            idempotence_key=f"turtuk-order-{order.id}-attempt-{attempts + 1}",
        )
    except YookassaError as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc

    yookassa_payment_id = response.get("id")
    confirmation_url = (response.get("confirmation") or {}).get("confirmation_url")
    if not yookassa_payment_id or not confirmation_url:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="ЮKassa вернула ответ без id платежа или confirmation_url",
        )

    payment = Payment(
        order_id=order.id,
        yookassa_payment_id=yookassa_payment_id,
        status=_YOOKASSA_STATUS_MAP.get(response.get("status"), PaymentStatus.PENDING),
        amount=order.total,
        currency="RUB",
        confirmation_url=confirmation_url,
    )
    session.add(payment)
    await session.commit()
    await session.refresh(payment)
    return payment


@router.post("/webhook")
async def payments_webhook(
    payload: PaymentWebhookRequest,
    session: AsyncSession = Depends(get_session),
    yookassa: YookassaClient = Depends(_yookassa_client_dependency),
) -> dict:
    yookassa_payment_id = payload.object.get("id")
    if not yookassa_payment_id:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="в вебхуке нет id платежа"
        )

    payment = (
        await session.execute(
            select(Payment).where(Payment.yookassa_payment_id == yookassa_payment_id)
        )
    ).scalar_one_or_none()
    if payment is None:
        # Платёж не наш (или ещё не создан у нас) — отвечаем 200, чтобы ЮKassa
        # не долбила ретраями чужую/неизвестную нотификацию, но никак её
        # не обрабатываем.
        return {"status": "ignored"}

    try:
        confirmed = await yookassa.get_payment(yookassa_payment_id)
    except YookassaError as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc

    real_status = _YOOKASSA_STATUS_MAP.get(confirmed.get("status"), PaymentStatus.PENDING)

    method_raw = (confirmed.get("payment_method") or {}).get("type")
    try:
        payment.payment_method = PaymentMethod(method_raw) if method_raw else payment.payment_method
    except ValueError:
        pass  # неизвестный ЮKassa способ оплаты — не наша забота, статус важнее

    if real_status == PaymentStatus.SUCCEEDED and payment.status != PaymentStatus.SUCCEEDED:
        payment.status = PaymentStatus.SUCCEEDED
        order = await session.get(Order, payment.order_id)
        order.payment_status = OrderPaymentStatus.PAID
    elif real_status == PaymentStatus.CANCELED and payment.status != PaymentStatus.CANCELED:
        payment.status = PaymentStatus.CANCELED
        order = await session.get(Order, payment.order_id)
        # Не понижаем уже оплаченный заказ: отменённый повторный платёж не
        # должен отменять оплату, прошедшую раньше по другой попытке.
        if order.payment_status != OrderPaymentStatus.PAID:
            order.payment_status = OrderPaymentStatus.FAILED

    await session.commit()
    return {"status": "ok"}
