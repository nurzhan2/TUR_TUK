"""Клиент ЮKassa REST API v3 через httpx, без стороннего SDK — тот же приём,
что уже применён к SMS-провайдерам (`app/core/sms.py`) и загрузке в S3.

Redirect-flow: мы не выбираем способ оплаты сами (`payment_method_data` не
передаём) — ЮKassa показывает клиенту страницу выбора карта/СБП по
настройкам магазина в её личном кабинете. Это и есть структурная причина,
почему в системе нет "наличных": единственный код, создающий платёж, никогда
не предлагает такой вариант, а `PaymentMethod` (см. app/models/payment.py)
такого значения не содержит вовсе.
"""

from __future__ import annotations

import uuid

import httpx

from app.core.config import Settings, get_settings

_BASE_URL = "https://api.yookassa.ru/v3"


class YookassaError(RuntimeError):
    """ЮKassa API отказала, не настроена, или ответ не разобрать."""


class YookassaClient:
    def __init__(self, shop_id: str, secret_key: str) -> None:
        self._auth = (shop_id, secret_key)

    async def create_payment(
        self,
        *,
        amount: float,
        currency: str,
        description: str,
        return_url: str,
        order_id: int,
    ) -> dict:
        """POST /payments. `Idempotence-Key` обязателен у ЮKassa — без него
        повтор запроса (например, ретрай по таймауту на нашей стороне) создал
        бы второй платёж на тот же заказ вместо того, чтобы просто вернуть
        уже созданный."""
        body = {
            "amount": {"value": f"{amount:.2f}", "currency": currency},
            "capture": True,
            "confirmation": {"type": "redirect", "return_url": return_url},
            "description": description,
            # order_id в metadata — подстраховка сверх нашей связки по
            # yookassa_payment_id: пригодится, если когда-нибудь понадобится
            # сверка со стороны ЮKassa (выгрузка, поддержка) без похода в нашу БД.
            "metadata": {"order_id": str(order_id)},
        }
        async with httpx.AsyncClient(timeout=15) as client:
            resp = await client.post(
                f"{_BASE_URL}/payments",
                json=body,
                auth=self._auth,
                headers={"Idempotence-Key": str(uuid.uuid4())},
            )
        if resp.status_code >= 300:
            raise YookassaError(f"ЮKassa create payment: {resp.status_code} {resp.text}")
        return resp.json()

    async def get_payment(self, yookassa_payment_id: str) -> dict:
        """GET /payments/{id} — источник правды о статусе платежа.

        Вебхук (`POST /payments/webhook`) НЕ доверяет статусу из собственного
        тела запроса: у ЮKassa нет HMAC-подписи вебхуков, кто угодно может
        прислать POST с телом `{"object": {"status": "succeeded", ...}}` на
        публичный эндпоинт. Единственная защита — переспросить статус здесь,
        авторизовавшись своим `secret_key`: подделать этот запрос может только
        тот, у кого есть наш секрет, то есть мы сами.
        """
        async with httpx.AsyncClient(timeout=15) as client:
            resp = await client.get(f"{_BASE_URL}/payments/{yookassa_payment_id}", auth=self._auth)
        if resp.status_code >= 300:
            raise YookassaError(f"ЮKassa get payment: {resp.status_code} {resp.text}")
        return resp.json()


def get_yookassa_client(settings: Settings | None = None) -> YookassaClient:
    settings = settings or get_settings()
    if not (settings.yookassa_shop_id and settings.yookassa_secret_key):
        raise YookassaError(
            "ЮKassa не настроена: нужны YOOKASSA_SHOP_ID/YOOKASSA_SECRET_KEY"
        )
    return YookassaClient(settings.yookassa_shop_id, settings.yookassa_secret_key)
