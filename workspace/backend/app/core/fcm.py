"""Реализация `NotificationSender` через Firebase Cloud Messaging.

Отдельный модуль от `app/core/notifications.py` нарочно (см. пояснение там):
провайдер из брифа не выбран окончательно, и код конкретного API не должен
тянуться в модуль абстракции. Legacy HTTP-API FCM (`fcm.googleapis.com/fcm/send`,
авторизация заголовком `key=<server key>`) выбран вместо HTTP v1 — тот не
требует OAuth2 service account, только один секрет, тем же приёмом простоты,
что и `SmsRuProvider`/`TwilioProvider` в `app/core/sms.py` (httpx напрямую,
без SDK).

`send(user_id, ...)` сам находит токен устройства пользователя — интерфейс
`NotificationSender.send()` не принимает сессию БД (см. бриф: сигнатура
`send(user_id, title, body)`), поэтому здесь открывается собственная сессия,
как в фоновых задачах `app/services/order_notifications.py`.
"""

from __future__ import annotations

import httpx

from app.core.notifications import NotificationSendError, NotificationSender
from app.db.session import async_session_factory
from app.models.user import User

_FCM_SEND_URL = "https://fcm.googleapis.com/fcm/send"


class FcmSender(NotificationSender):
    def __init__(self, server_key: str) -> None:
        self._server_key = server_key

    async def send(self, user_id: int, title: str, body: str) -> None:
        token = await self._device_token(user_id)
        if token is None:
            # Устройство ещё не зарегистрировано (клиентское приложение пока
            # не присылало fcm_token) — слать некуда, это не ошибка провайдера.
            return

        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.post(
                _FCM_SEND_URL,
                headers={
                    "Authorization": f"key={self._server_key}",
                    "Content-Type": "application/json",
                },
                json={"to": token, "notification": {"title": title, "body": body}},
            )
        if resp.status_code >= 300:
            raise NotificationSendError(f"fcm: {resp.status_code} {resp.text}")

    async def _device_token(self, user_id: int) -> str | None:
        async with async_session_factory() as session:
            user = await session.get(User, user_id)
            return user.fcm_token if user is not None else None
