from typing import Any

from pydantic import BaseModel, ConfigDict

from app.models.payment import PaymentStatus


class PaymentCreateRequest(BaseModel):
    order_id: int


class PaymentCreateResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    order_id: int
    status: PaymentStatus
    confirmation_url: str


class PaymentWebhookRequest(BaseModel):
    """Тело нотификации ЮKassa: `{"type": "notification", "event": "...",
    "object": {...}}`. Держим её как «сырую» модель — `object` разбирается
    руками в хендлере, а не Pydantic-схемой: ЮKassa присылает разный набор
    полей на разные события, а нам из всего этого нужен только `id` платежа
    (остальное перепроверяется через `GET /payments/{id}`, см.
    app/core/yookassa.py — тело вебхука на веру не принимается)."""

    type: str | None = None
    event: str | None = None
    object: dict[str, Any] = {}
