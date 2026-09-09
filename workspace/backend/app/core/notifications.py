"""Push-уведомления за абстракцией — провайдер (FCM, RuStore Push, другой) не
выбран владельцем окончательно (см. бриф, open_question про push-провайдер),
поэтому бизнес-логика (роутеры/сервисы заказа) обращается только к
`NotificationSender`, а не к конкретному API. Тот же приём, что `SmsProvider`
в `app/core/sms.py` для SMS.

Конкретная реализация (`FcmSender`) — в ОТДЕЛЬНОМ модуле (`app/core/fcm.py`),
а не здесь: фабрика импортирует её только при выборе провайдера, чтобы смена
NOTIFICATION_PROVIDER не тянула за собой код чужого провайдера.
"""

from __future__ import annotations

import abc

from app.core.config import Settings, get_settings


class NotificationSendError(RuntimeError):
    """Провайдер отказал или не настроен — уведомление не ушло."""


class NotificationSender(abc.ABC):
    @abc.abstractmethod
    async def send(self, user_id: int, title: str, body: str) -> None: ...


def get_notification_sender(settings: Settings | None = None) -> NotificationSender:
    settings = settings or get_settings()
    if settings.notification_provider != "fcm":
        raise NotificationSendError(
            f"неизвестный NOTIFICATION_PROVIDER={settings.notification_provider!r}"
        )
    from app.core.fcm import FcmSender

    if not settings.fcm_server_key:
        raise NotificationSendError(
            "FCM выбран, но не настроен: нужен FCM_SERVER_KEY "
            "(доступ к консоли Firebase у владельца пока под вопросом — см. бриф)"
        )
    return FcmSender(settings.fcm_server_key)
