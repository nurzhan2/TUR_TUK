"""Композиция push-уведомлений по заказу: кого и о чём уведомлять.

Router (`app/api/orders.py`) вызывает эти функции через `BackgroundTasks` —
после ответа клиенту, чтобы отправка уведомления не задерживала HTTP-ответ
и не роняла его при сбое провайдера. Функции принимают уже готовые данные
заказа (не сессию запроса): дожидаться `BackgroundTasks` сессия зависимости
`get_session()` уже закрыта (FastAPI закрывает `yield`-зависимости до того,
как Starlette выполняет фоновые задачи), поэтому запросы к чекерам ролей
здесь открывают СВОЮ сессию через `async_session_factory`.

Ни то, ни другое не импортирует FCM напрямую — только интерфейс
`NotificationSender` (см. app/core/notifications.py).
"""

from __future__ import annotations

import logging

from sqlalchemy import select

from app.core.notifications import NotificationSendError, NotificationSender
from app.core.rbac import ADMIN_ROLES
from app.db.session import async_session_factory
from app.models.order import Order, OrderStatus
from app.models.role import Role, RoleCode
from app.models.user import User

_logger = logging.getLogger(__name__)

# Только эти четыре перехода уведомляют клиента (бриф, deliverable:
# «Push-уведомления клиенту: заказ принят, собирается, доставляется,
# доставлен»). CREATED — сам факт оформления, не смена статуса силами
# курьера/админа; CANCELLED в списке брифа нет.
_CLIENT_STATUS_MESSAGES: dict[OrderStatus, str] = {
    OrderStatus.ACCEPTED: "Ваш заказ №{order_id} принят",
    OrderStatus.ASSEMBLING: "Ваш заказ №{order_id} собирается",
    OrderStatus.DELIVERING: "Ваш заказ №{order_id} доставляется",
    OrderStatus.DELIVERED: "Ваш заказ №{order_id} доставлен",
}


async def notify_order_status_changed(
    sender: NotificationSender, *, user_id: int, order_id: int, new_status: OrderStatus
) -> None:
    title = _CLIENT_STATUS_MESSAGES.get(new_status)
    if title is None:
        return
    await sender.send(user_id, title.format(order_id=order_id), "TUR TUK")


async def _admin_user_ids(session) -> list[int]:
    result = await session.execute(
        select(User.id).join(Role, User.role_id == Role.id).where(Role.code.in_(ADMIN_ROLES))
    )
    return list(result.scalars().all())


async def _free_courier_user_ids(session) -> list[int]:
    """«Свободный курьер» — курьер, за которым сейчас не числится заказ
    в незавершённом курьерском цикле (см. `OrderStatus` в app/models/order.py):
    он либо ещё ничего не вёз, либо уже сдал/отменил предыдущий заказ."""
    busy_couriers = select(Order.courier_id).where(
        Order.courier_id.is_not(None),
        Order.status.notin_([OrderStatus.DELIVERED, OrderStatus.CANCELLED]),
    )
    result = await session.execute(
        select(User.id)
        .join(Role, User.role_id == Role.id)
        .where(Role.code == RoleCode.COURIER.value, User.id.notin_(busy_couriers))
    )
    return list(result.scalars().all())


async def notify_new_order(
    sender: NotificationSender, *, order_id: int, hotel_name: str, room_number: str, total: float
) -> None:
    """Новый заказ — администратору и свободным курьерам (бриф, deliverable
    «Уведомления: новый заказ для администратора; новый заказ для курьера»)."""
    title = f"Новый заказ №{order_id}"
    body = f"{hotel_name}, комната {room_number}, {total:.0f} ₽"

    async with async_session_factory() as session:
        admin_ids = await _admin_user_ids(session)
        courier_ids = await _free_courier_user_ids(session)

    for recipient_id in {*admin_ids, *courier_ids}:
        try:
            await sender.send(recipient_id, title, body)
        except NotificationSendError:
            # Один недоступный получатель не должен обрывать рассылку
            # остальным администраторам/курьерам о том же заказе.
            _logger.warning("не удалось отправить уведомление о заказе %s пользователю %s",
                             order_id, recipient_id, exc_info=True)
