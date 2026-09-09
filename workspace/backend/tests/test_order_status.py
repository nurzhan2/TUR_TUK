"""PATCH /orders/{id}/status: допустимые переходы pending(created)→accepted→
assembling→delivering→delivered, плюс created→cancelled (отклонение).
Роли: courier/admin принимают и отклоняют, admin/collector переводят
в assembling, только курьер переводит в delivering/delivered. Каждый
переход пишет строку в order_status_log.

Реальный Postgres, тот же контур, что у остальных файлов — свой префикс
телефона (+70007, свободен после +70000..+70006) и заказы заводятся
напрямую через сессию (тот же приём, что в test_rbac.py), а не через
POST /orders: этому файлу нужен полный набор ролей вокруг заказа, а не
сценарий оформления.
"""

import pytest
import pytest_asyncio
from sqlalchemy import delete, select

from app.core.security import create_access_token
from app.db.session import async_session_factory
from app.models.order import Order, OrderStatus
from app.models.order_status_log import OrderStatusLog
from app.models.role import Role, RoleCode
from app.models.user import User

TEST_PHONE_PREFIX = "+70007"


async def _wipe_order_status_test_data() -> None:
    async with async_session_factory() as session:
        user_ids = select(User.id).where(User.phone.like(f"{TEST_PHONE_PREFIX}%"))
        order_ids = select(Order.id).where(
            Order.user_id.in_(user_ids) | Order.courier_id.in_(user_ids)
        )
        await session.execute(delete(OrderStatusLog).where(OrderStatusLog.order_id.in_(order_ids)))
        await session.execute(delete(Order).where(Order.user_id.in_(user_ids)))
        await session.execute(delete(Order).where(Order.courier_id.in_(user_ids)))
        await session.execute(delete(User).where(User.phone.like(f"{TEST_PHONE_PREFIX}%")))
        await session.commit()


@pytest_asyncio.fixture(autouse=True)
async def _cleanup_order_status_data():
    await _wipe_order_status_test_data()
    yield
    await _wipe_order_status_test_data()


async def _make_user(role_code: str, suffix: str) -> tuple[User, str]:
    async with async_session_factory() as session:
        result = await session.execute(select(Role).where(Role.code == role_code))
        role = result.scalar_one()
        user = User(phone=f"{TEST_PHONE_PREFIX}{suffix}", role_id=role.id)
        session.add(user)
        await session.commit()
        await session.refresh(user)
    return user, create_access_token(user.id)


async def _make_order(*, user_id: int, courier_id: int | None = None,
                       status_: OrderStatus = OrderStatus.CREATED) -> Order:
    async with async_session_factory() as session:
        order = Order(
            user_id=user_id,
            courier_id=courier_id,
            status=status_,
            total=3500,
            hotel_name="Test Hotel",
            room_number="101",
        )
        session.add(order)
        await session.commit()
        await session.refresh(order)
    return order


async def _status_log(order_id: int) -> list[OrderStatusLog]:
    async with async_session_factory() as session:
        result = await session.execute(
            select(OrderStatusLog).where(OrderStatusLog.order_id == order_id).order_by(OrderStatusLog.id)
        )
        return list(result.scalars().all())


def _auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


async def _patch_status(client, order_id: int, token: str, new_status: str):
    return await client.patch(
        f"/orders/{order_id}/status",
        json={"status": new_status},
        headers=_auth(token),
    )


# --- базовое -----------------------------------------------------------


async def test_update_status_without_token_is_401(client):
    resp = await client.patch("/orders/1/status", json={"status": "accepted"})
    assert resp.status_code == 401


async def test_update_status_unknown_order_is_404(client):
    _, token = await _make_user(RoleCode.ADMIN.value, "001")
    resp = await _patch_status(client, 999999999, token, "accepted")
    assert resp.status_code == 404


# --- полный happy-path -------------------------------------------------


async def test_full_transition_happy_path_records_history(client):
    client_user, _ = await _make_user(RoleCode.CLIENT.value, "010")
    courier, courier_token = await _make_user(RoleCode.COURIER.value, "011")
    admin, admin_token = await _make_user(RoleCode.ADMIN.value, "012")
    order = await _make_order(user_id=client_user.id)

    resp = await _patch_status(client, order.id, courier_token, "accepted")
    assert resp.status_code == 200
    assert resp.json()["status"] == "accepted"
    assert resp.json()["courier_id"] == courier.id

    resp = await _patch_status(client, order.id, admin_token, "assembling")
    assert resp.status_code == 200
    assert resp.json()["status"] == "assembling"

    resp = await _patch_status(client, order.id, courier_token, "delivering")
    assert resp.status_code == 200
    assert resp.json()["status"] == "delivering"

    resp = await _patch_status(client, order.id, courier_token, "delivered")
    assert resp.status_code == 200
    assert resp.json()["status"] == "delivered"

    log = await _status_log(order.id)
    assert [(row.from_status, row.to_status) for row in log] == [
        (OrderStatus.CREATED, OrderStatus.ACCEPTED),
        (OrderStatus.ACCEPTED, OrderStatus.ASSEMBLING),
        (OrderStatus.ASSEMBLING, OrderStatus.DELIVERING),
        (OrderStatus.DELIVERING, OrderStatus.DELIVERED),
    ]
    assert log[0].changed_by == courier.id
    assert log[1].changed_by == admin.id
    assert log[2].changed_by == courier.id
    assert log[3].changed_by == courier.id


# --- принятие/отклонение: courier/admin ---------------------------------


async def test_courier_can_accept_unassigned_order(client):
    client_user, _ = await _make_user(RoleCode.CLIENT.value, "020")
    courier, courier_token = await _make_user(RoleCode.COURIER.value, "021")
    order = await _make_order(user_id=client_user.id)

    resp = await _patch_status(client, order.id, courier_token, "accepted")
    assert resp.status_code == 200
    assert resp.json()["courier_id"] == courier.id


async def test_admin_can_accept_order(client):
    client_user, _ = await _make_user(RoleCode.CLIENT.value, "030")
    _, admin_token = await _make_user(RoleCode.ADMIN.value, "031")
    order = await _make_order(user_id=client_user.id)

    resp = await _patch_status(client, order.id, admin_token, "accepted")
    assert resp.status_code == 200
    assert resp.json()["status"] == "accepted"


async def test_admin_can_reject_order(client):
    client_user, _ = await _make_user(RoleCode.CLIENT.value, "040")
    _, admin_token = await _make_user(RoleCode.ADMIN.value, "041")
    order = await _make_order(user_id=client_user.id)

    resp = await _patch_status(client, order.id, admin_token, "cancelled")
    assert resp.status_code == 200
    assert resp.json()["status"] == "cancelled"


async def test_courier_can_reject_unassigned_order(client):
    client_user, _ = await _make_user(RoleCode.CLIENT.value, "050")
    _, courier_token = await _make_user(RoleCode.COURIER.value, "051")
    order = await _make_order(user_id=client_user.id)

    resp = await _patch_status(client, order.id, courier_token, "cancelled")
    assert resp.status_code == 200
    assert resp.json()["status"] == "cancelled"


async def test_client_cannot_accept_order(client):
    client_user, client_token = await _make_user(RoleCode.CLIENT.value, "060")
    order = await _make_order(user_id=client_user.id)

    resp = await _patch_status(client, order.id, client_token, "accepted")
    assert resp.status_code == 403


async def test_support_cannot_accept_order(client):
    client_user, _ = await _make_user(RoleCode.CLIENT.value, "070")
    _, support_token = await _make_user(RoleCode.SUPPORT.value, "071")
    order = await _make_order(user_id=client_user.id)

    resp = await _patch_status(client, order.id, support_token, "accepted")
    assert resp.status_code == 403


async def test_courier_cannot_accept_order_assigned_to_other_courier(client):
    client_user, _ = await _make_user(RoleCode.CLIENT.value, "080")
    _, courier_a_token = await _make_user(RoleCode.COURIER.value, "081")
    courier_b, _ = await _make_user(RoleCode.COURIER.value, "082")
    order = await _make_order(user_id=client_user.id, courier_id=courier_b.id)

    resp = await _patch_status(client, order.id, courier_a_token, "accepted")
    assert resp.status_code == 403


# --- assembling: только admin/collector ---------------------------------


async def test_collector_can_move_to_assembling(client):
    client_user, _ = await _make_user(RoleCode.CLIENT.value, "090")
    courier, courier_token = await _make_user(RoleCode.COURIER.value, "091")
    _, collector_token = await _make_user(RoleCode.COLLECTOR.value, "092")
    order = await _make_order(user_id=client_user.id, courier_id=courier.id,
                               status_=OrderStatus.CREATED)
    resp = await _patch_status(client, order.id, courier_token, "accepted")
    assert resp.status_code == 200

    resp = await _patch_status(client, order.id, collector_token, "assembling")
    assert resp.status_code == 200
    assert resp.json()["status"] == "assembling"


async def test_courier_cannot_move_to_assembling(client):
    client_user, _ = await _make_user(RoleCode.CLIENT.value, "100")
    courier, courier_token = await _make_user(RoleCode.COURIER.value, "101")
    order = await _make_order(user_id=client_user.id, courier_id=courier.id,
                               status_=OrderStatus.ACCEPTED)

    resp = await _patch_status(client, order.id, courier_token, "assembling")
    assert resp.status_code == 403


async def test_support_cannot_move_to_assembling(client):
    """Формулировка задачи называет ровно admin/collector — support сюда не входит."""
    client_user, _ = await _make_user(RoleCode.CLIENT.value, "110")
    _, support_token = await _make_user(RoleCode.SUPPORT.value, "111")
    order = await _make_order(user_id=client_user.id, status_=OrderStatus.ACCEPTED)

    resp = await _patch_status(client, order.id, support_token, "assembling")
    assert resp.status_code == 403


# --- delivering/delivered: только назначенный курьер --------------------


async def test_admin_cannot_move_to_delivering(client):
    client_user, _ = await _make_user(RoleCode.CLIENT.value, "120")
    courier, _ = await _make_user(RoleCode.COURIER.value, "121")
    _, admin_token = await _make_user(RoleCode.ADMIN.value, "122")
    order = await _make_order(user_id=client_user.id, courier_id=courier.id,
                               status_=OrderStatus.ASSEMBLING)

    resp = await _patch_status(client, order.id, admin_token, "delivering")
    assert resp.status_code == 403


async def test_other_courier_cannot_move_to_delivering(client):
    client_user, _ = await _make_user(RoleCode.CLIENT.value, "130")
    courier_a, _ = await _make_user(RoleCode.COURIER.value, "131")
    _, courier_b_token = await _make_user(RoleCode.COURIER.value, "132")
    order = await _make_order(user_id=client_user.id, courier_id=courier_a.id,
                               status_=OrderStatus.ASSEMBLING)

    resp = await _patch_status(client, order.id, courier_b_token, "delivering")
    assert resp.status_code == 403


async def test_assigned_courier_can_move_to_delivering_and_delivered(client):
    client_user, _ = await _make_user(RoleCode.CLIENT.value, "140")
    courier, courier_token = await _make_user(RoleCode.COURIER.value, "141")
    order = await _make_order(user_id=client_user.id, courier_id=courier.id,
                               status_=OrderStatus.ASSEMBLING)

    resp = await _patch_status(client, order.id, courier_token, "delivering")
    assert resp.status_code == 200

    resp = await _patch_status(client, order.id, courier_token, "delivered")
    assert resp.status_code == 200
    assert resp.json()["status"] == "delivered"


# --- недопустимые переходы ------------------------------------------------


async def test_invalid_status_transition_rejected(client):
    """Курьер пытается перевести свежесозданный заказ сразу в "delivering",
    минуя "accepted"/"assembling" — переход не входит в граф допустимых
    и должен быть отвергнут независимо от того, что роль курьера сама
    по себе вправе выставлять "delivering" на других заказах."""
    client_user, _ = await _make_user(RoleCode.CLIENT.value, "150")
    _, courier_token = await _make_user(RoleCode.COURIER.value, "151")
    order = await _make_order(user_id=client_user.id, status_=OrderStatus.CREATED)

    resp = await _patch_status(client, order.id, courier_token, "delivering")
    assert resp.status_code == 422

    log = await _status_log(order.id)
    assert log == []


async def test_invalid_transition_from_accepted_to_cancelled_rejected(client):
    """Отклонить можно только ещё не принятый заказ — после "accepted"
    единственный дальнейший шаг — "assembling"."""
    client_user, _ = await _make_user(RoleCode.CLIENT.value, "160")
    _, admin_token = await _make_user(RoleCode.ADMIN.value, "161")
    order = await _make_order(user_id=client_user.id, status_=OrderStatus.ACCEPTED)

    resp = await _patch_status(client, order.id, admin_token, "cancelled")
    assert resp.status_code == 422


async def test_no_transition_from_delivered(client):
    client_user, _ = await _make_user(RoleCode.CLIENT.value, "170")
    courier, courier_token = await _make_user(RoleCode.COURIER.value, "171")
    order = await _make_order(user_id=client_user.id, courier_id=courier.id,
                               status_=OrderStatus.DELIVERED)

    resp = await _patch_status(client, order.id, courier_token, "delivering")
    assert resp.status_code == 422
