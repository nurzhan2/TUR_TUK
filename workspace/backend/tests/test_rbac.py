import pytest
import pytest_asyncio
from sqlalchemy import delete, select

from app.core.security import create_access_token
from app.db.session import async_session_factory
from app.models.order import Order, OrderStatus
from app.models.role import Role, RoleCode
from app.models.user import User

# Отдельный от test_auth.py префикс — чтобы чистки двух файлов не пересекались
# и не гонялись за строками друг друга.
TEST_PHONE_PREFIX = "+70001"

ALL_ROLES = [r.value for r in RoleCode]
ADMIN_ROLES = [RoleCode.ADMIN.value, RoleCode.OWNER.value, RoleCode.DIRECTOR.value]
NON_ADMIN_ROLES = [r for r in ALL_ROLES if r not in ADMIN_ROLES]


def _phone(suffix: str) -> str:
    return f"{TEST_PHONE_PREFIX}{suffix}"


async def _wipe_rbac_test_data() -> None:
    """Полная чистка по префиксу телефона. Заказы — двумя отдельными DELETE
    (по `user_id` и по `courier_id`), а не одним OR: FK `orders.user_id` и
    `orders.courier_id` на `users.id` без `ON DELETE CASCADE`, и если хотя бы
    одна ссылающаяся строка уцелеет, удаление пользователя упадёт
    `ForeignKeyViolationError`. Два прохода надёжнее одного OR по общему
    подзапросу — сначала снимаем оба вида ссылок, только потом пользователей.
    """
    async with async_session_factory() as session:
        test_user_ids = select(User.id).where(User.phone.like(f"{TEST_PHONE_PREFIX}%"))
        await session.execute(delete(Order).where(Order.user_id.in_(test_user_ids)))
        await session.execute(delete(Order).where(Order.courier_id.in_(test_user_ids)))
        await session.execute(delete(User).where(User.phone.like(f"{TEST_PHONE_PREFIX}%")))
        await session.commit()


@pytest_asyncio.fixture(autouse=True)
async def _cleanup_rbac_data():
    # Чистим и ДО, и ПОСЛЕ: если предыдущий прогон упал где-то посередине
    # (процесс убит, сеть легла) и не успел вычистить за собой — мусор с тем
    # же телефоном иначе валит следующий прогон `UNIQUE constraint`
    # ещё до того, как тест успел сказать, в чём дело.
    await _wipe_rbac_test_data()
    yield
    await _wipe_rbac_test_data()


async def _make_user(role_code: str, suffix: str) -> tuple[User, str]:
    async with async_session_factory() as session:
        result = await session.execute(select(Role).where(Role.code == role_code))
        role = result.scalar_one()
        user = User(phone=_phone(suffix), role_id=role.id)
        session.add(user)
        await session.commit()
        await session.refresh(user)
    return user, create_access_token(user.id)


async def _make_order(*, user_id: int, courier_id: int | None = None) -> Order:
    async with async_session_factory() as session:
        order = Order(
            user_id=user_id,
            courier_id=courier_id,
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


# --- /admin/* — доступ только персоналу (admin/owner/director) -----------


async def test_admin_products_no_token_is_401(client):
    resp = await client.get("/api/admin/products")
    assert resp.status_code == 401


async def test_admin_products_garbage_token_is_401(client):
    resp = await client.get("/api/admin/products", headers=_auth("not-a-jwt"))
    assert resp.status_code == 401


async def test_admin_products_refresh_token_is_401(client):
    """Токен типа refresh не должен открывать доступ вместо access."""
    from app.core.security import create_refresh_token

    user, _ = await _make_user(RoleCode.ADMIN.value, "012")
    refresh_token = create_refresh_token(user.id)

    resp = await client.get("/api/admin/products", headers=_auth(refresh_token))
    assert resp.status_code == 401


@pytest.mark.parametrize("role_code", ADMIN_ROLES)
async def test_admin_products_allowed_roles_get_200(client, role_code):
    _, token = await _make_user(role_code, f"1{ADMIN_ROLES.index(role_code)}")
    resp = await client.get("/api/admin/products", headers=_auth(token))
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)


@pytest.mark.parametrize("role_code", NON_ADMIN_ROLES)
async def test_admin_products_other_roles_get_403(client, role_code):
    _, token = await _make_user(role_code, f"2{NON_ADMIN_ROLES.index(role_code)}")
    resp = await client.get("/api/admin/products", headers=_auth(token))
    assert resp.status_code == 403


# --- /orders — курьер видит только свои заказы, клиент — только свои -----


async def test_courier_can_view_own_order(client):
    courier, token = await _make_user(RoleCode.COURIER.value, "020")
    order = await _make_order(user_id=courier.id, courier_id=courier.id)

    resp = await client.get(f"/orders/{order.id}", headers=_auth(token))
    assert resp.status_code == 200
    assert resp.json()["id"] == order.id


async def test_courier_cannot_view_other_couriers_order(client):
    courier_a, token_a = await _make_user(RoleCode.COURIER.value, "021")
    courier_b, _ = await _make_user(RoleCode.COURIER.value, "022")
    client_user, _ = await _make_user(RoleCode.CLIENT.value, "023")
    order = await _make_order(user_id=client_user.id, courier_id=courier_b.id)

    resp = await client.get(f"/orders/{order.id}", headers=_auth(token_a))
    assert resp.status_code == 403


async def test_courier_without_assigned_order_gets_403_not_404(client):
    """Заказ существует (не выдуман), просто не назначен этому курьеру — 403, не 404."""
    courier, token = await _make_user(RoleCode.COURIER.value, "024")
    other_client, _ = await _make_user(RoleCode.CLIENT.value, "025")
    order = await _make_order(user_id=other_client.id, courier_id=None)

    resp = await client.get(f"/orders/{order.id}", headers=_auth(token))
    assert resp.status_code == 403


async def test_courier_list_only_returns_own_orders(client):
    courier_a, token_a = await _make_user(RoleCode.COURIER.value, "026")
    courier_b, _ = await _make_user(RoleCode.COURIER.value, "027")
    client_user, _ = await _make_user(RoleCode.CLIENT.value, "028")
    own_order = await _make_order(user_id=client_user.id, courier_id=courier_a.id)
    await _make_order(user_id=client_user.id, courier_id=courier_b.id)

    resp = await client.get("/orders", headers=_auth(token_a))
    assert resp.status_code == 200
    ids = {row["id"] for row in resp.json()}
    assert ids == {own_order.id}


async def test_client_can_view_own_order(client):
    client_user, token = await _make_user(RoleCode.CLIENT.value, "030")
    order = await _make_order(user_id=client_user.id)

    resp = await client.get(f"/orders/{order.id}", headers=_auth(token))
    assert resp.status_code == 200


async def test_client_cannot_view_other_clients_order(client):
    client_a, token_a = await _make_user(RoleCode.CLIENT.value, "031")
    client_b, _ = await _make_user(RoleCode.CLIENT.value, "032")
    order = await _make_order(user_id=client_b.id)

    resp = await client.get(f"/orders/{order.id}", headers=_auth(token_a))
    assert resp.status_code == 403


async def test_client_list_only_returns_own_orders(client):
    client_a, token_a = await _make_user(RoleCode.CLIENT.value, "033")
    client_b, _ = await _make_user(RoleCode.CLIENT.value, "034")
    own_order = await _make_order(user_id=client_a.id)
    await _make_order(user_id=client_b.id)

    resp = await client.get("/orders", headers=_auth(token_a))
    assert resp.status_code == 200
    ids = {row["id"] for row in resp.json()}
    assert ids == {own_order.id}


async def test_unknown_order_is_404(client):
    _, token = await _make_user(RoleCode.ADMIN.value, "040")
    resp = await client.get("/orders/999999999", headers=_auth(token))
    assert resp.status_code == 404


@pytest.mark.parametrize(
    "role_code",
    [RoleCode.ADMIN.value, RoleCode.OWNER.value, RoleCode.DIRECTOR.value,
     RoleCode.SUPPORT.value, RoleCode.COLLECTOR.value],
)
async def test_staff_roles_can_view_any_order(client, role_code):
    client_user, _ = await _make_user(RoleCode.CLIENT.value, "050")
    courier, _ = await _make_user(RoleCode.COURIER.value, "051")
    order = await _make_order(user_id=client_user.id, courier_id=courier.id)
    staff_user, staff_token = await _make_user(role_code, f"5{2 + ALL_ROLES.index(role_code)}")

    resp = await client.get(f"/orders/{order.id}", headers=_auth(staff_token))
    assert resp.status_code == 200


async def test_orders_without_token_is_401(client):
    resp = await client.get("/orders")
    assert resp.status_code == 401
