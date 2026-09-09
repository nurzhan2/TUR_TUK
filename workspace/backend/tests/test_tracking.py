"""Геотрекинг курьера: WebSocket, права по владению заказом, восстановление
последней позиции при переподключении.

Реальный Postgres, тот же контур WS-тестов, что у `test_chat.py`: httpx_ws
`ASGIWebSocketTransport` умеет и обычные запросы, и апгрейд на WebSocket,
в одном event loop с остальным тестом.
"""

import json

import pytest_asyncio
from httpx import AsyncClient
from httpx_ws import aconnect_ws
from httpx_ws.transport import ASGIWebSocketTransport
from sqlalchemy import delete, select

from app.core.security import create_access_token
from app.db.session import async_session_factory
from app.main import app
from app.models.courier_location import CourierLocation
from app.models.order import Order, OrderStatus
from app.models.role import Role, RoleCode
from app.models.user import User

TEST_PHONE_PREFIX = "+70006"


async def _wipe_tracking_test_data() -> None:
    async with async_session_factory() as session:
        user_ids = select(User.id).where(User.phone.like(f"{TEST_PHONE_PREFIX}%"))
        order_ids = select(Order.id).where(
            Order.user_id.in_(user_ids) | Order.courier_id.in_(user_ids)
        )
        await session.execute(
            delete(CourierLocation).where(CourierLocation.order_id.in_(order_ids))
        )
        await session.execute(delete(Order).where(Order.id.in_(order_ids)))
        await session.execute(delete(User).where(User.phone.like(f"{TEST_PHONE_PREFIX}%")))
        await session.commit()


@pytest_asyncio.fixture(autouse=True)
async def _cleanup_tracking_data():
    await _wipe_tracking_test_data()
    yield
    await _wipe_tracking_test_data()


async def _make_user(role_code: str, suffix: str) -> tuple[User, str]:
    async with async_session_factory() as session:
        result = await session.execute(select(Role).where(Role.code == role_code))
        role = result.scalar_one()
        user = User(phone=f"{TEST_PHONE_PREFIX}{suffix}", role_id=role.id)
        session.add(user)
        await session.commit()
        await session.refresh(user)
    return user, create_access_token(user.id)


async def _make_order(user_id: int, courier_id: int | None = None) -> Order:
    async with async_session_factory() as session:
        order = Order(
            user_id=user_id,
            courier_id=courier_id,
            status=OrderStatus.DELIVERING if courier_id else OrderStatus.CREATED,
            total=3500,
            hotel_name="Test Hotel",
            room_number="202",
        )
        session.add(order)
        await session.commit()
        await session.refresh(order)
    return order


def _ws_client() -> AsyncClient:
    return AsyncClient(transport=ASGIWebSocketTransport(app=app), base_url="http://test")


def _ws_url(order_id: int, token: str) -> str:
    return f"/ws/courier-location/{order_id}?token={token}"


# --- доступ -------------------------------------------------------------


async def test_ws_rejects_invalid_token():
    from httpx_ws import WebSocketDisconnect

    client_user, _ = await _make_user(RoleCode.CLIENT.value, "01")
    order = await _make_order(client_user.id)

    async with _ws_client() as http:
        try:
            async with aconnect_ws(_ws_url(order.id, "not-a-jwt"), http):
                pass
            assert False, "ожидался отказ в подключении"
        except WebSocketDisconnect as exc:
            assert exc.code == 4401


async def test_ws_unknown_order_is_closed_with_4404():
    from httpx_ws import WebSocketDisconnect

    _, token = await _make_user(RoleCode.CLIENT.value, "02")

    async with _ws_client() as http:
        try:
            async with aconnect_ws(_ws_url(999999999, token), http):
                pass
            assert False, "ожидался отказ в подключении"
        except WebSocketDisconnect as exc:
            assert exc.code == 4404


async def test_ws_forbidden_for_other_clients_order():
    from httpx_ws import WebSocketDisconnect

    owner, _ = await _make_user(RoleCode.CLIENT.value, "03")
    _, other_token = await _make_user(RoleCode.CLIENT.value, "04")
    order = await _make_order(owner.id)

    async with _ws_client() as http:
        try:
            async with aconnect_ws(_ws_url(order.id, other_token), http):
                pass
            assert False, "ожидался отказ в подключении"
        except WebSocketDisconnect as exc:
            assert exc.code == 4403


async def test_ws_forbidden_for_courier_not_assigned_to_order():
    from httpx_ws import WebSocketDisconnect

    owner, _ = await _make_user(RoleCode.CLIENT.value, "05")
    assigned_courier, _ = await _make_user(RoleCode.COURIER.value, "06")
    _, other_courier_token = await _make_user(RoleCode.COURIER.value, "07")
    order = await _make_order(owner.id, courier_id=assigned_courier.id)

    async with _ws_client() as http:
        try:
            async with aconnect_ws(_ws_url(order.id, other_courier_token), http):
                pass
            assert False, "ожидался отказ в подключении"
        except WebSocketDisconnect as exc:
            assert exc.code == 4403


# --- доставка координат ---------------------------------------------------


async def test_courier_location_reaches_subscribed_client():
    """Требование задачи буквально: курьер отправляет — клиент получает."""
    client_user, client_token = await _make_user(RoleCode.CLIENT.value, "10")
    courier, courier_token = await _make_user(RoleCode.COURIER.value, "11")
    order = await _make_order(client_user.id, courier_id=courier.id)

    async with _ws_client() as http:
        async with aconnect_ws(_ws_url(order.id, client_token), http) as client_ws:
            async with aconnect_ws(_ws_url(order.id, courier_token), http) as courier_ws:
                await courier_ws.send_text(json.dumps({"lat": 36.6018, "lon": 31.6156}))
                update = await client_ws.receive_json(timeout=2)

    assert update["lat"] == 36.6018
    assert update["lon"] == 31.6156
    assert update["courier_id"] == courier.id
    assert update["order_id"] == order.id


async def test_location_is_persisted_in_courier_locations():
    client_user, _ = await _make_user(RoleCode.CLIENT.value, "12")
    courier, courier_token = await _make_user(RoleCode.COURIER.value, "13")
    order = await _make_order(client_user.id, courier_id=courier.id)

    async with _ws_client() as http:
        async with aconnect_ws(_ws_url(order.id, courier_token), http) as courier_ws:
            await courier_ws.send_text(json.dumps({"lat": 36.5, "lon": 31.5}))
            # раунд-трип: убедиться, что запись в БД уже закоммичена к моменту
            # получения широковещательной рассылки этим же сокетом.
            await courier_ws.receive_json(timeout=2)

    async with async_session_factory() as session:
        result = await session.execute(
            select(CourierLocation).where(CourierLocation.order_id == order.id)
        )
        rows = result.scalars().all()

    assert len(rows) == 1
    assert float(rows[0].latitude) == 36.5
    assert float(rows[0].longitude) == 31.5
    assert rows[0].courier_id == courier.id


async def test_non_courier_cannot_send_location():
    """Клиент подписан на трек, но не может двигать координаты курьера."""
    from httpx_ws import WebSocketDisconnect

    client_user, client_token = await _make_user(RoleCode.CLIENT.value, "14")
    courier, _ = await _make_user(RoleCode.COURIER.value, "15")
    order = await _make_order(client_user.id, courier_id=courier.id)

    async with _ws_client() as http:
        async with aconnect_ws(_ws_url(order.id, client_token), http) as client_ws:
            await client_ws.send_text(json.dumps({"lat": 1.0, "lon": 1.0}))
            got_broadcast = True
            try:
                await client_ws.receive_json(timeout=0.5)
            except (TimeoutError, WebSocketDisconnect):
                got_broadcast = False
            assert not got_broadcast, "клиентская отправка не должна создавать точку трека"

    async with async_session_factory() as session:
        result = await session.execute(
            select(CourierLocation).where(CourierLocation.order_id == order.id)
        )
        assert result.scalars().first() is None


async def test_invalid_point_payload_is_ignored():
    courier, courier_token = await _make_user(RoleCode.COURIER.value, "16")
    client_user, _ = await _make_user(RoleCode.CLIENT.value, "17")
    order = await _make_order(client_user.id, courier_id=courier.id)

    async with _ws_client() as http:
        async with aconnect_ws(_ws_url(order.id, courier_token), http) as courier_ws:
            await courier_ws.send_text("не json")
            await courier_ws.send_text(json.dumps({"lat": 999, "lon": 30}))  # вне диапазона
            await courier_ws.send_text(json.dumps({"lat": 36.6, "lon": 31.6}))
            update = await courier_ws.receive_json(timeout=2)

    assert update["lat"] == 36.6
    assert update["lon"] == 31.6


# --- восстановление при переподключении -----------------------------------


async def test_reconnect_receives_last_known_position():
    client_user, client_token = await _make_user(RoleCode.CLIENT.value, "20")
    courier, courier_token = await _make_user(RoleCode.COURIER.value, "21")
    order = await _make_order(client_user.id, courier_id=courier.id)

    async with _ws_client() as http:
        async with aconnect_ws(_ws_url(order.id, courier_token), http) as courier_ws:
            async with aconnect_ws(_ws_url(order.id, client_token), http) as client_ws:
                await courier_ws.send_text(json.dumps({"lat": 36.7, "lon": 31.7}))
                await client_ws.receive_json(timeout=2)

        # клиент переподключается уже без открытого сокета курьера
        async with aconnect_ws(_ws_url(order.id, client_token), http) as client_ws2:
            restored = await client_ws2.receive_json(timeout=2)

    assert restored["lat"] == 36.7
    assert restored["lon"] == 31.7


async def test_no_prior_location_means_no_snapshot_on_connect():
    from httpx_ws import WebSocketDisconnect

    client_user, client_token = await _make_user(RoleCode.CLIENT.value, "22")
    order = await _make_order(client_user.id)

    async with _ws_client() as http:
        async with aconnect_ws(_ws_url(order.id, client_token), http) as client_ws:
            got_snapshot = True
            try:
                await client_ws.receive_json(timeout=0.5)
            except (TimeoutError, WebSocketDisconnect):
                got_snapshot = False
            assert not got_snapshot
