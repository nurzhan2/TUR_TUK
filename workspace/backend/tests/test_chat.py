"""Чат клиент↔оператор по заказу: WebSocket, история, автоответ бота.

Реальный Postgres, тот же контур, что у остальных тестов. WS-тесты не могут
использовать httpx `ASGITransport` напрямую — он ASGI websocket-scope не
понимает и превращает апгрейд в обычный HTTP-запрос (404 на маршруте,
объявленном только под websocket). `httpx_ws.transport.ASGIWebSocketTransport`
умеет и то и другое, работает в том же event loop, что и остальной тест —
никакого отдельного потока/цикла событий, как у `starlette.testclient`, и
никакого риска столкнуть asyncpg-соединения из разных event loop'ов.
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
from app.models.chat_message import ChatMessage
from app.models.order import Order, OrderStatus
from app.models.role import Role, RoleCode
from app.models.user import User
from app.routers.chat import _FALLBACK_ANSWER

TEST_PHONE_PREFIX = "+70005"


async def _wipe_chat_test_data() -> None:
    async with async_session_factory() as session:
        user_ids = select(User.id).where(User.phone.like(f"{TEST_PHONE_PREFIX}%"))
        order_ids = select(Order.id).where(Order.user_id.in_(user_ids))
        await session.execute(delete(ChatMessage).where(ChatMessage.order_id.in_(order_ids)))
        await session.execute(delete(Order).where(Order.user_id.in_(user_ids)))
        await session.execute(delete(User).where(User.phone.like(f"{TEST_PHONE_PREFIX}%")))
        await session.commit()


@pytest_asyncio.fixture(autouse=True)
async def _cleanup_chat_data():
    await _wipe_chat_test_data()
    yield
    await _wipe_chat_test_data()


async def _make_user(role_code: str, suffix: str) -> tuple[User, str]:
    async with async_session_factory() as session:
        result = await session.execute(select(Role).where(Role.code == role_code))
        role = result.scalar_one()
        user = User(phone=f"{TEST_PHONE_PREFIX}{suffix}", role_id=role.id)
        session.add(user)
        await session.commit()
        await session.refresh(user)
    return user, create_access_token(user.id)


async def _make_order(user_id: int) -> Order:
    async with async_session_factory() as session:
        order = Order(
            user_id=user_id,
            status=OrderStatus.CREATED,
            total=1500,
            hotel_name="Test Hotel",
            room_number="101",
        )
        session.add(order)
        await session.commit()
        await session.refresh(order)
    return order


def _auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def _ws_client() -> AsyncClient:
    return AsyncClient(transport=ASGIWebSocketTransport(app=app), base_url="http://test")


def _ws_url(order_id: int, token: str) -> str:
    return f"/ws/chat/{order_id}?token={token}"


# --- WebSocket: доступ ------------------------------------------------------


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


# --- WebSocket: доставка сообщений ------------------------------------------


async def test_client_message_reaches_operator_via_websocket():
    """Требование задачи буквально: клиент отправляет — оператор получает."""
    client_user, client_token = await _make_user(RoleCode.CLIENT.value, "10")
    _, operator_token = await _make_user(RoleCode.SUPPORT.value, "11")
    order = await _make_order(client_user.id)

    async with _ws_client() as http:
        async with aconnect_ws(_ws_url(order.id, client_token), http) as client_ws:
            async with aconnect_ws(_ws_url(order.id, operator_token), http) as operator_ws:
                # первое сообщение клиента запускает бота — разбираем и его,
                # чтобы не мешал следующей проверке.
                await client_ws.send_text(json.dumps({"body": "первое сообщение"}))
                await client_ws.receive_json(timeout=2)  # свой же echo
                await client_ws.receive_json(timeout=2)  # автоответ бота
                await operator_ws.receive_json(timeout=2)
                await operator_ws.receive_json(timeout=2)

                await client_ws.send_text(json.dumps({"body": "уточните по доставке заказа"}))
                delivered = await operator_ws.receive_json(timeout=2)

    assert delivered["body"] == "уточните по доставке заказа"
    assert delivered["sender_id"] == client_user.id
    assert delivered["is_bot"] is False


async def test_plain_text_message_without_json_is_accepted():
    client_user, client_token = await _make_user(RoleCode.CLIENT.value, "12")
    order = await _make_order(client_user.id)

    async with _ws_client() as http:
        async with aconnect_ws(_ws_url(order.id, client_token), http) as client_ws:
            await client_ws.send_text("просто текст без JSON")
            echo = await client_ws.receive_json(timeout=2)
            assert echo["body"] == "просто текст без JSON"


# --- Чат-бот -----------------------------------------------------------------


async def test_first_client_message_gets_faq_bot_reply():
    client_user, client_token = await _make_user(RoleCode.CLIENT.value, "20")
    order = await _make_order(client_user.id)

    async with _ws_client() as http:
        async with aconnect_ws(_ws_url(order.id, client_token), http) as client_ws:
            await client_ws.send_text(json.dumps({"body": "подскажите, как оплатить заказ?"}))
            await client_ws.receive_json(timeout=2)  # echo своего сообщения
            bot_reply = await client_ws.receive_json(timeout=2)

    assert bot_reply["is_bot"] is True
    assert bot_reply["sender_id"] is None
    assert "оплата" in bot_reply["body"].lower() or "сбп" in bot_reply["body"].lower()


async def test_first_client_message_without_keyword_match_gets_fallback():
    client_user, client_token = await _make_user(RoleCode.CLIENT.value, "21")
    order = await _make_order(client_user.id)

    async with _ws_client() as http:
        async with aconnect_ws(_ws_url(order.id, client_token), http) as client_ws:
            await client_ws.send_text(json.dumps({"body": "просто хочу поздороваться с вами"}))
            await client_ws.receive_json(timeout=2)
            bot_reply = await client_ws.receive_json(timeout=2)

    assert bot_reply["is_bot"] is True
    assert bot_reply["body"] == _FALLBACK_ANSWER


async def test_bot_replies_only_to_first_client_message():
    from httpx_ws import WebSocketDisconnect

    client_user, client_token = await _make_user(RoleCode.CLIENT.value, "22")
    order = await _make_order(client_user.id)

    async with _ws_client() as http:
        async with aconnect_ws(_ws_url(order.id, client_token), http) as client_ws:
            await client_ws.send_text(json.dumps({"body": "первое сообщение клиента"}))
            await client_ws.receive_json(timeout=2)  # echo
            await client_ws.receive_json(timeout=2)  # автоответ бота

            await client_ws.send_text(json.dumps({"body": "второе сообщение клиента"}))
            second_echo = await client_ws.receive_json(timeout=2)
            assert second_echo["body"] == "второе сообщение клиента"

            got_extra_reply = True
            try:
                await client_ws.receive_json(timeout=0.5)
            except (TimeoutError, WebSocketDisconnect):
                got_extra_reply = False
            assert not got_extra_reply, "бот не должен отвечать повторно"


# --- История чата: GET /chat/{order_id}/messages ----------------------------


async def test_chat_history_requires_auth(client):
    resp = await client.get("/chat/1/messages")
    assert resp.status_code == 401


async def test_chat_history_unknown_order_is_404(client):
    _, token = await _make_user(RoleCode.CLIENT.value, "30")
    resp = await client.get("/chat/999999999/messages", headers=_auth(token))
    assert resp.status_code == 404


async def test_chat_history_forbidden_for_other_client(client):
    owner, _ = await _make_user(RoleCode.CLIENT.value, "31")
    _, other_token = await _make_user(RoleCode.CLIENT.value, "32")
    order = await _make_order(owner.id)

    resp = await client.get(f"/chat/{order.id}/messages", headers=_auth(other_token))
    assert resp.status_code == 403


async def test_chat_history_visible_to_staff(client):
    owner, _ = await _make_user(RoleCode.CLIENT.value, "33")
    _, staff_token = await _make_user(RoleCode.SUPPORT.value, "34")
    order = await _make_order(owner.id)

    resp = await client.get(f"/chat/{order.id}/messages", headers=_auth(staff_token))
    assert resp.status_code == 200
    assert resp.json() == []


async def test_chat_history_returns_messages_in_order(client):
    client_user, client_token = await _make_user(RoleCode.CLIENT.value, "35")
    order = await _make_order(client_user.id)

    async with _ws_client() as http:
        async with aconnect_ws(_ws_url(order.id, client_token), http) as client_ws:
            await client_ws.send_text(json.dumps({"body": "как оплатить заказ?"}))
            await client_ws.receive_json(timeout=2)
            await client_ws.receive_json(timeout=2)

    resp = await client.get(f"/chat/{order.id}/messages", headers=_auth(client_token))
    assert resp.status_code == 200
    body = resp.json()
    assert len(body) == 2
    assert body[0]["is_bot"] is False
    assert body[0]["sender_id"] == client_user.id
    assert body[1]["is_bot"] is True
    assert body[1]["id"] > body[0]["id"]
