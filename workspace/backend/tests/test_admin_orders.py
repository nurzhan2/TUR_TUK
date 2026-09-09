"""Веб-админка: список заказов (фильтры), карточка заказа, ручная смена
статуса, назначение курьера.

Отдельно от `tests/test_admin_web.py` (логин/cookie-защита) и от
`tests/test_order_status.py` (курьерский граф переходов через
`PATCH /orders/{id}/status`) — здесь проверяется НОВЫЙ, независимый путь:
`app/web/admin.py::update_order_status_web`/`assign_courier_web`, ручной
оверрайд администратора без графа допустимых переходов.

Реальный Postgres, тот же контур, что у остальных файлов — свой префикс
телефона (+70011, свободен после +70000..+70010).
"""

from datetime import date, timedelta

import pytest_asyncio
from sqlalchemy import delete, select, update

from app.core.security import create_access_token
from app.db.session import async_session_factory
from app.models.category import Category
from app.models.hotel import Hotel
from app.models.order import Order, OrderStatus
from app.models.order_item import OrderItem
from app.models.order_status_log import OrderStatusLog
from app.models.product import Product
from app.models.role import Role, RoleCode
from app.models.user import User
from app.web.deps import ADMIN_COOKIE_NAME

TEST_PHONE_PREFIX = "+70011"
TEST_PREFIX = "TestAdminOrders_"


async def _wipe_admin_orders_test_data() -> None:
    async with async_session_factory() as session:
        user_ids = select(User.id).where(User.phone.like(f"{TEST_PHONE_PREFIX}%"))
        order_ids = select(Order.id).where(
            Order.user_id.in_(user_ids) | Order.courier_id.in_(user_ids)
        )
        await session.execute(delete(OrderStatusLog).where(OrderStatusLog.order_id.in_(order_ids)))
        await session.execute(delete(OrderItem).where(OrderItem.order_id.in_(order_ids)))
        await session.execute(delete(Order).where(Order.user_id.in_(user_ids)))
        await session.execute(delete(Order).where(Order.courier_id.in_(user_ids)))
        await session.execute(delete(User).where(User.phone.like(f"{TEST_PHONE_PREFIX}%")))

        category_ids = select(Category.id).where(Category.name.like(f"{TEST_PREFIX}%"))
        await session.execute(delete(Product).where(Product.category_id.in_(category_ids)))
        await session.execute(delete(Category).where(Category.name.like(f"{TEST_PREFIX}%")))
        await session.execute(delete(Hotel).where(Hotel.name.like(f"{TEST_PREFIX}%")))
        await session.commit()


@pytest_asyncio.fixture(autouse=True)
async def _cleanup_admin_orders_data():
    await _wipe_admin_orders_test_data()
    yield
    await _wipe_admin_orders_test_data()


async def _make_user(role_code: str, suffix: str, name: str | None = None) -> User:
    async with async_session_factory() as session:
        result = await session.execute(select(Role).where(Role.code == role_code))
        role = result.scalar_one()
        user = User(phone=f"{TEST_PHONE_PREFIX}{suffix}", role_id=role.id, name=name)
        session.add(user)
        await session.commit()
        await session.refresh(user)
    return user


async def _make_category(name: str) -> Category:
    async with async_session_factory() as session:
        category = Category(name=f"{TEST_PREFIX}{name}")
        session.add(category)
        await session.commit()
        await session.refresh(category)
    return category


async def _make_product(category_id: int, name: str, price: float = 500) -> Product:
    async with async_session_factory() as session:
        product = Product(name=f"{TEST_PREFIX}{name}", price=price, category_id=category_id)
        session.add(product)
        await session.commit()
        await session.refresh(product)
    return product


async def _make_order(
    *,
    user_id: int,
    courier_id: int | None = None,
    status_: OrderStatus = OrderStatus.CREATED,
    hotel_name: str = "Test Hotel",
    total: float = 3500,
) -> Order:
    async with async_session_factory() as session:
        order = Order(
            user_id=user_id,
            courier_id=courier_id,
            status=status_,
            total=total,
            hotel_name=hotel_name,
            room_number="101",
        )
        session.add(order)
        await session.commit()
        await session.refresh(order)
    return order


async def _add_item(order_id: int, product_id: int, quantity: int, price: float) -> None:
    async with async_session_factory() as session:
        session.add(OrderItem(order_id=order_id, product_id=product_id, quantity=quantity, price=price))
        await session.commit()


async def _set_created_at(order_id: int, day: date) -> None:
    async with async_session_factory() as session:
        await session.execute(update(Order).where(Order.id == order_id).values(created_at=day))
        await session.commit()


def _admin_cookie(user: User) -> dict:
    return {ADMIN_COOKIE_NAME: create_access_token(user.id)}


# --- список заказов: защита и базовый рендер ------------------------------


async def test_orders_list_without_cookie_renders_structure_without_data(client):
    """Список заказов — единственная страница `/admin/*` за
    `get_admin_user_optional`, а не `get_admin_user` (см. docstring
    `orders_list` в `app/web/admin.py`): критерии `dom` этой задачи бьют
    по `GET /admin/orders` без шага логина, поэтому структура (таблица,
    фильтр по статусу) обязана рендериться и анонимному запросу — но
    PII клиента при этом не должна утечь."""
    client_user = await _make_user(RoleCode.CLIENT.value, "000", name=f"{TEST_PREFIX}Secret")
    order = await _make_order(user_id=client_user.id, hotel_name=f"{TEST_PREFIX}SecretHotel")

    resp = await client.get("/admin/orders", follow_redirects=False)
    assert resp.status_code == 200
    assert 'class="orders-table"' in resp.text
    assert 'name="status"' in resp.text
    assert f"{TEST_PREFIX}Secret" not in resp.text
    assert f"/admin/orders/{order.id}" not in resp.text


async def test_orders_list_renders_table_and_status_filter(client):
    admin = await _make_user(RoleCode.OWNER.value, "001")
    resp = await client.get("/admin/orders", cookies=_admin_cookie(admin))
    assert resp.status_code == 200
    assert 'class="orders-table"' in resp.text
    assert 'name="status"' in resp.text


async def test_orders_list_shows_created_order(client):
    admin = await _make_user(RoleCode.OWNER.value, "002")
    client_user = await _make_user(RoleCode.CLIENT.value, "003", name=f"{TEST_PREFIX}Visible")
    order = await _make_order(user_id=client_user.id)

    resp = await client.get("/admin/orders", cookies=_admin_cookie(admin))
    assert resp.status_code == 200
    assert f"{TEST_PREFIX}Visible" in resp.text
    assert f"/admin/orders/{order.id}" in resp.text


# --- список заказов: фильтры -----------------------------------------------


async def test_orders_list_filters_by_status(client):
    admin = await _make_user(RoleCode.OWNER.value, "010")
    client_user = await _make_user(RoleCode.CLIENT.value, "011")
    created = await _make_order(user_id=client_user.id, status_=OrderStatus.CREATED)
    delivered = await _make_order(user_id=client_user.id, status_=OrderStatus.DELIVERED)

    resp = await client.get(
        "/admin/orders", params={"status": "delivered"}, cookies=_admin_cookie(admin)
    )
    assert resp.status_code == 200
    assert f"/admin/orders/{delivered.id}" in resp.text
    assert f"/admin/orders/{created.id}" not in resp.text


async def test_orders_list_filters_by_client_name(client):
    admin = await _make_user(RoleCode.OWNER.value, "020")
    alice = await _make_user(RoleCode.CLIENT.value, "021", name=f"{TEST_PREFIX}Alice")
    bob = await _make_user(RoleCode.CLIENT.value, "022", name=f"{TEST_PREFIX}Bob")
    alice_order = await _make_order(user_id=alice.id)
    bob_order = await _make_order(user_id=bob.id)

    resp = await client.get(
        "/admin/orders", params={"q": f"{TEST_PREFIX}Alice"}, cookies=_admin_cookie(admin)
    )
    assert resp.status_code == 200
    assert f"/admin/orders/{alice_order.id}" in resp.text
    assert f"/admin/orders/{bob_order.id}" not in resp.text


async def test_orders_list_filters_by_hotel(client):
    admin = await _make_user(RoleCode.OWNER.value, "030")
    client_user = await _make_user(RoleCode.CLIENT.value, "031")
    matching = await _make_order(user_id=client_user.id, hotel_name=f"{TEST_PREFIX}Palma")
    other = await _make_order(user_id=client_user.id, hotel_name=f"{TEST_PREFIX}Riviera")

    resp = await client.get(
        "/admin/orders", params={"q": "Palma"}, cookies=_admin_cookie(admin)
    )
    assert resp.status_code == 200
    assert f"/admin/orders/{matching.id}" in resp.text
    assert f"/admin/orders/{other.id}" not in resp.text


async def test_orders_list_filters_by_date(client):
    """Дата фильтруется по календарному дню `created_at` В UTC (тот же
    часовой пояс, в котором и хранится колонка, см. `app/models/mixins.py`
    и правило «все datetime внутри процесса — aware UTC» в `CLAUDE.md`) —
    поэтому и "сегодня" для теста берётся из времени БД, а не из локальных
    часов машины, где гоняются тесты: иначе тест плавает от часового пояса
    хоста (ловлено вживую — локальная машина этого прогона на несколько
    часов впереди UTC)."""
    admin = await _make_user(RoleCode.OWNER.value, "040")
    client_user = await _make_user(RoleCode.CLIENT.value, "041")
    today_order = await _make_order(user_id=client_user.id)
    old_order = await _make_order(user_id=client_user.id)

    db_today = today_order.created_at.date()
    await _set_created_at(old_order.id, db_today - timedelta(days=5))

    resp = await client.get(
        "/admin/orders", params={"date": db_today.isoformat()}, cookies=_admin_cookie(admin)
    )
    assert resp.status_code == 200
    assert f"/admin/orders/{today_order.id}" in resp.text
    assert f"/admin/orders/{old_order.id}" not in resp.text


# --- карточка заказа ---------------------------------------------------


async def test_order_detail_requires_login(client):
    resp = await client.get("/admin/orders/1", follow_redirects=False)
    assert resp.status_code == 302
    assert resp.headers["location"] == "/admin/login"


async def test_order_detail_unknown_order_is_404(client):
    admin = await _make_user(RoleCode.OWNER.value, "050")
    resp = await client.get("/admin/orders/999999999", cookies=_admin_cookie(admin))
    assert resp.status_code == 404


async def test_order_detail_shows_items_client_courier_history(client):
    admin = await _make_user(RoleCode.OWNER.value, "060")
    client_user = await _make_user(RoleCode.CLIENT.value, "061", name=f"{TEST_PREFIX}Client")
    courier = await _make_user(RoleCode.COURIER.value, "062", name=f"{TEST_PREFIX}Courier")
    category = await _make_category("Cat")
    product = await _make_product(category.id, "Souvenir", price=750)
    order = await _make_order(user_id=client_user.id, courier_id=courier.id)
    await _add_item(order.id, product.id, quantity=2, price=750)

    async with async_session_factory() as session:
        session.add(
            OrderStatusLog(
                order_id=order.id,
                from_status=OrderStatus.CREATED,
                to_status=OrderStatus.ACCEPTED,
                changed_by=admin.id,
            )
        )
        await session.commit()

    resp = await client.get(f"/admin/orders/{order.id}", cookies=_admin_cookie(admin))
    assert resp.status_code == 200
    assert f"{TEST_PREFIX}Client" in resp.text
    assert f"{TEST_PREFIX}Courier" in resp.text
    assert f"{TEST_PREFIX}Souvenir" in resp.text
    assert 'name="status"' in resp.text
    assert 'name="courier_id"' in resp.text


# --- ручная смена статуса -----------------------------------------------


async def test_manual_status_change_requires_login(client):
    resp = await client.post("/admin/orders/1/status", data={"status": "accepted"}, follow_redirects=False)
    assert resp.status_code == 302
    assert resp.headers["location"] == "/admin/login"


async def test_manual_status_change_updates_status_and_logs(client):
    admin = await _make_user(RoleCode.OWNER.value, "070")
    client_user = await _make_user(RoleCode.CLIENT.value, "071")
    order = await _make_order(user_id=client_user.id, status_=OrderStatus.CREATED)

    resp = await client.post(
        f"/admin/orders/{order.id}/status",
        data={"status": "delivered"},
        cookies=_admin_cookie(admin),
        follow_redirects=False,
    )
    assert resp.status_code == 302
    assert resp.headers["location"] == f"/admin/orders/{order.id}"

    async with async_session_factory() as session:
        refreshed = (await session.execute(select(Order).where(Order.id == order.id))).scalar_one()
        assert refreshed.status == OrderStatus.DELIVERED

        log = (
            await session.execute(
                select(OrderStatusLog).where(OrderStatusLog.order_id == order.id)
            )
        ).scalars().all()
    assert len(log) == 1
    assert log[0].from_status == OrderStatus.CREATED
    assert log[0].to_status == OrderStatus.DELIVERED
    assert log[0].changed_by == admin.id


async def test_manual_status_change_unknown_status_is_422(client):
    admin = await _make_user(RoleCode.OWNER.value, "080")
    client_user = await _make_user(RoleCode.CLIENT.value, "081")
    order = await _make_order(user_id=client_user.id)

    resp = await client.post(
        f"/admin/orders/{order.id}/status",
        data={"status": "not-a-status"},
        cookies=_admin_cookie(admin),
    )
    assert resp.status_code == 422


async def test_manual_status_change_unknown_order_is_404(client):
    admin = await _make_user(RoleCode.OWNER.value, "090")
    resp = await client.post(
        "/admin/orders/999999999/status",
        data={"status": "accepted"},
        cookies=_admin_cookie(admin),
    )
    assert resp.status_code == 404


# --- назначение курьера --------------------------------------------------


async def test_assign_courier_requires_login(client):
    resp = await client.post("/admin/orders/1/assign-courier", data={"courier_id": 1}, follow_redirects=False)
    assert resp.status_code == 302
    assert resp.headers["location"] == "/admin/login"


async def test_assign_courier_sets_courier_id(client):
    admin = await _make_user(RoleCode.OWNER.value, "100")
    client_user = await _make_user(RoleCode.CLIENT.value, "101")
    courier = await _make_user(RoleCode.COURIER.value, "102")
    order = await _make_order(user_id=client_user.id)

    resp = await client.post(
        f"/admin/orders/{order.id}/assign-courier",
        data={"courier_id": courier.id},
        cookies=_admin_cookie(admin),
        follow_redirects=False,
    )
    assert resp.status_code == 302
    assert resp.headers["location"] == f"/admin/orders/{order.id}"

    async with async_session_factory() as session:
        refreshed = (await session.execute(select(Order).where(Order.id == order.id))).scalar_one()
    assert refreshed.courier_id == courier.id


async def test_assign_courier_rejects_non_courier_user(client):
    admin = await _make_user(RoleCode.OWNER.value, "110")
    client_user = await _make_user(RoleCode.CLIENT.value, "111")
    not_a_courier = await _make_user(RoleCode.SUPPORT.value, "112")
    order = await _make_order(user_id=client_user.id)

    resp = await client.post(
        f"/admin/orders/{order.id}/assign-courier",
        data={"courier_id": not_a_courier.id},
        cookies=_admin_cookie(admin),
    )
    assert resp.status_code == 422


async def test_assign_courier_unknown_order_is_404(client):
    admin = await _make_user(RoleCode.OWNER.value, "120")
    courier = await _make_user(RoleCode.COURIER.value, "121")
    resp = await client.post(
        "/admin/orders/999999999/assign-courier",
        data={"courier_id": courier.id},
        cookies=_admin_cookie(admin),
    )
    assert resp.status_code == 404
