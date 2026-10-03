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


_sender: NotificationSender | None = None


def get_notification_sender(settings: Settings | None = None) -> NotificationSender:
    """Один отправитель на процесс: FCM держит OAuth-токен в памяти, и
    пересоздавать его на каждый заказ значило бы лишний запрос к Google."""
    global _sender
    settings = settings or get_settings()
    if settings.notification_provider != "fcm":
        raise NotificationSendError(
            f"неизвестный NOTIFICATION_PROVIDER={settings.notification_provider!r}"
        )
    if _sender is not None:
        return _sender
    from app.core.fcm import FcmSender, load_service_account

    if not settings.fcm_service_account:
        raise NotificationSendError(
            "FCM не настроен: нужен FCM_SERVICE_ACCOUNT — путь к JSON-ключу сервисного "
            "аккаунта Firebase (Project settings → Service accounts → Generate new private key)"
        )
    _sender = FcmSender(load_service_account(settings.fcm_service_account))
    return _sender
