"""Геотрекинг курьера по заказу.

`WS /ws/courier-location/{order_id}?token=JWT` — курьер, назначенный на
заказ, шлёт `{"lat": .., "lon": ..}` каждые ~5 сек; клиент (владелец заказа)
и персонал подписаны на тот же order_id и получают обновления в реальном
времени. Комната держится в памяти процесса — тот же приём, что у чата
(`app/routers/chat.py`), тот же единственный воркер uvicorn без Redis.

Каждая точка трека пишется в `courier_locations` отдельной строкой (модель
уже так устроена — `recorded_at` вместо upsert одной "текущей" строки).
Последняя по времени строка — источник для восстановления при
переподключении: подключившийся сокет сразу получает её, не дожидаясь
следующего обновления от курьера.
"""

import json

from fastapi import APIRouter, Depends, Query, WebSocket, WebSocketDisconnect
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.rbac import STAFF_ROLES
from app.core.security import InvalidTokenError, decode_token
from app.db.session import get_session
from app.models.courier_location import CourierLocation
from app.models.order import Order
from app.models.role import RoleCode
from app.models.user import User

router = APIRouter(tags=["tracking"])


def _can_access_tracking(user: User, order: Order) -> bool:
    """Те же правила владения, что у `_can_view` в `app/api/orders.py`:
    персонал видит любой заказ, курьер — только тот, что назначен ему,
    клиент — только свой. Не переиспользуем ту функцию напрямую (она
    модуль-приватная в другом роутере) — тот же приём дублирования
    маленького правила доступа, что уже есть у `_can_access_chat`."""
    role = user.role.code
    if role in STAFF_ROLES:
        return True
    if role == RoleCode.COURIER.value:
        return order.courier_id == user.id
    return order.user_id == user.id


def _is_assigned_courier(user: User, order: Order) -> bool:
    """Отправлять координаты вправе только курьер, назначенный на ЭТОТ
    заказ — иначе чужой курьер мог бы задвигать трек в чужом заказе."""
    return user.role.code == RoleCode.COURIER.value and order.courier_id == user.id


async def _authenticate_ws(token: str, session: AsyncSession) -> User | None:
    try:
        payload = decode_token(token, expected_type="access")
        user_id = int(payload["sub"])
    except (InvalidTokenError, KeyError, TypeError, ValueError):
        return None

    result = await session.execute(
        select(User).options(selectinload(User.role)).where(User.id == user_id)
    )
    user = result.scalar_one_or_none()
    # Удалённый гость / уволенный курьер — как в REST (`get_current_user`).
    return user if user is not None and user.is_active else None


def _parse_point(raw: str) -> tuple[float, float] | None:
    try:
        data = json.loads(raw)
        lat = float(data["lat"])
        lon = float(data["lon"])
    except (json.JSONDecodeError, KeyError, TypeError, ValueError):
        return None
    if not (-90.0 <= lat <= 90.0 and -180.0 <= lon <= 180.0):
        return None
    return lat, lon


def _serialize(location: CourierLocation) -> dict:
    return {
        "order_id": location.order_id,
        "courier_id": location.courier_id,
        "lat": float(location.latitude),
        "lon": float(location.longitude),
        "recorded_at": location.recorded_at.isoformat(),
    }


async def _last_location(session: AsyncSession, order_id: int) -> CourierLocation | None:
    result = await session.execute(
        select(CourierLocation)
        .where(CourierLocation.order_id == order_id)
        .order_by(CourierLocation.recorded_at.desc(), CourierLocation.id.desc())
        .limit(1)
    )
    return result.scalars().first()


class _TrackingRoomManager:
    """Реестр открытых WS-соединений по order_id, в памяти процесса."""

    def __init__(self) -> None:
        self._rooms: dict[int, set[WebSocket]] = {}

    async def connect(self, order_id: int, websocket: WebSocket) -> None:
        await websocket.accept()
        self._rooms.setdefault(order_id, set()).add(websocket)

    def disconnect(self, order_id: int, websocket: WebSocket) -> None:
        room = self._rooms.get(order_id)
        if room is None:
            return
        room.discard(websocket)
        if not room:
            self._rooms.pop(order_id, None)

    async def broadcast(self, order_id: int, payload: dict) -> None:
        for websocket in list(self._rooms.get(order_id, ())):
            try:
                await websocket.send_json(payload)
            except Exception:
                self.disconnect(order_id, websocket)


_manager = _TrackingRoomManager()


@router.websocket("/ws/courier-location/{order_id}")
async def courier_location_websocket(
    websocket: WebSocket,
    order_id: int,
    token: str = Query(...),
    session: AsyncSession = Depends(get_session),
) -> None:
    user = await _authenticate_ws(token, session)
    if user is None:
        await websocket.close(code=4401)
        return

    order = await session.get(Order, order_id)
    if order is None:
        await websocket.close(code=4404)
        return

    if not _can_access_tracking(user, order):
        await websocket.close(code=4403)
        return

    can_send = _is_assigned_courier(user, order)

    await _manager.connect(order_id, websocket)
    try:
        last = await _last_location(session, order_id)
        if last is not None:
            await websocket.send_json(_serialize(last))

        while True:
            raw = await websocket.receive_text()
            if not can_send:
                # Клиент и персонал только подписаны на трек — координаты
                # шлёт исключительно назначенный курьер, всё остальное молча
                # игнорируется (тот же приём, что пустое тело в чате).
                continue

            point = _parse_point(raw)
            if point is None:
                continue
            lat, lon = point

            location = CourierLocation(
                courier_id=user.id, order_id=order_id, latitude=lat, longitude=lon
            )
            session.add(location)
            await session.commit()
            await session.refresh(location)
            await _manager.broadcast(order_id, _serialize(location))
    except WebSocketDisconnect:
        pass
    finally:
        _manager.disconnect(order_id, websocket)
