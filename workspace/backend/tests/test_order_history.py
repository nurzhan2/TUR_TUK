"""GET /orders/history: список заказов клиента с деталями, сортировка по
дате (новые сверху); область видимости та же, что у GET /orders (клиент —
только свои, курьер — назначенные ему, персонал — все).
POST /orders/{id}/repeat: новый заказ из позиций старого с проверкой
доступности товаров — недоступный товар не проваливает повтор целиком,
а выпадает из него с предупреждением (частичный список).

Реальный Postgres, тот же контур, что у остальных файлов — свой префикс
телефона (+70009, свободен после +70000..+70008) и свой префикс имён
отелей/категорий для очистки.
"""

import pytest_asyncio
from httpx import AsyncClient
from sqlalchemy import delete, select

from app.core.security import create_access_token
from app.db.session import async_session_factory
from app.models.category import Category
from app.models.hotel import Hotel
from app.models.order import Order
from app.models.order_item import OrderItem
from app.models.product import Product
from app.models.role import Role, RoleCode
from app.models.user import User

TEST_PHONE_PREFIX = "+70009"
TEST_PREFIX = "TestOrderHistory_"

EXPENSIVE_PRICE = 2000


async def _wipe_history_test_data() -> None:
    async with async_session_factory() as session:
        user_ids = select(User.id).where(User.phone.like(f"{TEST_PHONE_PREFIX}%"))
        order_ids = select(Order.id).where(
            Order.user_id.in_(user_ids) | Order.courier_id.in_(user_ids)
        )
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
async def _cleanup_history_data():
    await _wipe_history_test_data()
    yield
    await _wipe_history_test_data()


async def _make_user(suffix: str, role_code: str = RoleCode.CLIENT.value) -> tuple[User, str]:
    async with async_session_factory() as session:
        result = await session.execute(select(Role).where(Role.code == role_code))
        role = result.scalar_one()
        user = User(phone=f"{TEST_PHONE_PREFIX}{suffix}", role_id=role.id)
        session.add(user)
        await session.commit()
        await session.refresh(user)
    return user, create_access_token(user.id)


async def _make_hotel(name: str) -> Hotel:
    async with async_session_factory() as session:
        hotel = Hotel(name=f"{TEST_PREFIX}{name}")
        session.add(hotel)
        await session.commit()
        await session.refresh(hotel)
    return hotel


async def _make_category(name: str) -> Category:
    async with async_session_factory() as session:
        category = Category(name=f"{TEST_PREFIX}{name}")
        session.add(category)
        await session.commit()
        await session.refresh(category)
    return category


async def _make_product(
    name: str, category_id: int, *, price: float = EXPENSIVE_PRICE, is_available: bool = True
) -> Product:
    async with async_session_factory() as session:
        product = Product(
            name=f"{TEST_PREFIX}{name}",
            description="описание",
            price=price,
            category_id=category_id,
            is_available=is_available,
        )
        session.add(product)
        await session.commit()
        await session.refresh(product)
    return product


async def _set_available(product_id: int, is_available: bool) -> None:
    async with async_session_factory() as session:
        product = await session.get(Product, product_id)
        product.is_available = is_available
        await session.commit()


def _auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


async def _create_order(
    client: AsyncClient, token: str, hotel_name: str, room_number: str, items: list[dict]
):
    return await client.post(
        "/orders",
        json={"hotel_name": hotel_name, "room_number": room_number, "items": items},
        headers=_auth(token),
    )


# --- GET /orders/history ---------------------------------------------------


async def test_history_without_token_is_401(client: AsyncClient):
    resp = await client.get("/orders/history")
    assert resp.status_code == 401


async def test_history_returns_orders_with_items_newest_first(client: AsyncClient):
    _, token = await _make_user("01")
    hotel = await _make_hotel("Hotel01")
    category = await _make_category("Category01")
    product = await _make_product("Product01", category.id)

    first = await _create_order(
        client, token, hotel.name, "101", [{"product_id": product.id, "quantity": 2}]
    )
    second = await _create_order(
        client, token, hotel.name, "102", [{"product_id": product.id, "quantity": 2}]
    )
    assert first.status_code == 201 and second.status_code == 201

    resp = await client.get("/orders/history", headers=_auth(token))
    assert resp.status_code == 200
    body = resp.json()
    assert [o["id"] for o in body] == [second.json()["id"], first.json()["id"]]

    newest = body[0]
    assert newest["room_number"] == "102"
    assert newest["items"] == [
        {
            "product_id": product.id,
            "product_name": product.name,
            "quantity": 2,
            "price": EXPENSIVE_PRICE,
        }
    ]
    assert "created_at" in newest


async def test_history_client_does_not_see_other_clients_orders(client: AsyncClient):
    _, token_a = await _make_user("02")
    _, token_b = await _make_user("03")
    hotel = await _make_hotel("Hotel02")
    category = await _make_category("Category02")
    product = await _make_product("Product02", category.id)

    created = await _create_order(
        client, token_a, hotel.name, "201", [{"product_id": product.id, "quantity": 2}]
    )
    assert created.status_code == 201

    resp = await client.get("/orders/history", headers=_auth(token_b))
    assert resp.status_code == 200
    assert resp.json() == []


async def test_history_staff_sees_all_orders(client: AsyncClient):
    _, client_token = await _make_user("04")
    _, admin_token = await _make_user("05", role_code=RoleCode.ADMIN.value)
    hotel = await _make_hotel("Hotel04")
    category = await _make_category("Category04")
    product = await _make_product("Product04", category.id)

    created = await _create_order(
        client, client_token, hotel.name, "301", [{"product_id": product.id, "quantity": 2}]
    )
    assert created.status_code == 201
    order_id = created.json()["id"]

    resp = await client.get("/orders/history", headers=_auth(admin_token))
    assert resp.status_code == 200
    assert order_id in [o["id"] for o in resp.json()]


async def test_history_courier_sees_only_assigned_orders(client: AsyncClient):
    _, client_token = await _make_user("06")
    courier, courier_token = await _make_user("07", role_code=RoleCode.COURIER.value)
    hotel = await _make_hotel("Hotel06")
    category = await _make_category("Category06")
    product = await _make_product("Product06", category.id)

    created = await _create_order(
        client, client_token, hotel.name, "401", [{"product_id": product.id, "quantity": 2}]
    )
    order_id = created.json()["id"]

    # Заказ пока никому не назначен — курьер его в своей истории не видит.
    resp_before = await client.get("/orders/history", headers=_auth(courier_token))
    assert resp_before.json() == []

    async with async_session_factory() as session:
        order = await session.get(Order, order_id)
        order.courier_id = courier.id
        await session.commit()

    resp_after = await client.get("/orders/history", headers=_auth(courier_token))
    assert [o["id"] for o in resp_after.json()] == [order_id]


# --- POST /orders/{id}/repeat -----------------------------------------------


async def test_repeat_without_token_is_401(client: AsyncClient):
    resp = await client.post("/orders/1/repeat")
    assert resp.status_code == 401


async def test_repeat_unknown_order_is_404(client: AsyncClient):
    _, token = await _make_user("08")
    resp = await client.post("/orders/999999999/repeat", headers=_auth(token))
    assert resp.status_code == 404


async def test_repeat_forbidden_for_other_users_order(client: AsyncClient):
    _, token_a = await _make_user("09")
    _, token_b = await _make_user("10")
    hotel = await _make_hotel("Hotel09")
    category = await _make_category("Category09")
    product = await _make_product("Product09", category.id)

    created = await _create_order(
        client, token_a, hotel.name, "501", [{"product_id": product.id, "quantity": 2}]
    )
    order_id = created.json()["id"]

    resp = await client.post(f"/orders/{order_id}/repeat", headers=_auth(token_b))
    assert resp.status_code == 403


async def test_repeat_creates_new_order_with_same_items(client: AsyncClient):
    _, token = await _make_user("11")
    hotel = await _make_hotel("Hotel11")
    category = await _make_category("Category11")
    product = await _make_product("Product11", category.id)

    created = await _create_order(
        client, token, hotel.name, "601", [{"product_id": product.id, "quantity": 2}]
    )
    order_id = created.json()["id"]

    resp = await client.post(f"/orders/{order_id}/repeat", headers=_auth(token))
    assert resp.status_code == 200
    body = resp.json()
    assert body["skipped_items"] == []
    assert body["warning"] is None
    assert body["order"]["id"] != order_id
    assert body["order"]["hotel_name"] == hotel.name
    assert body["order"]["room_number"] == "601"
    assert body["order"]["total"] == created.json()["total"]

    async with async_session_factory() as session:
        items = (
            await session.execute(
                select(OrderItem).where(OrderItem.order_id == body["order"]["id"])
            )
        ).scalars().all()
        assert len(items) == 1
        assert items[0].product_id == product.id
        assert items[0].quantity == 2


async def test_repeat_with_unavailable_item_returns_partial_list_with_warning(
    client: AsyncClient,
):
    """Критерий задачи: повтор заказа с недоступным товаром возвращает
    частичный список с предупреждением, а не проваливается целиком."""
    _, token = await _make_user("12")
    hotel = await _make_hotel("Hotel12")
    category = await _make_category("Category12")
    # available_product сам по себе набирает минимальную сумму заказа —
    # проверяем именно частичный повтор, а не смежный случай «остатка не
    # хватает на минимум» (он отдельным тестом ниже).
    available_product = await _make_product("ProductAvail12", category.id, price=3000)
    unavailable_product = await _make_product("ProductGone12", category.id, price=1000)

    created = await _create_order(
        client,
        token,
        hotel.name,
        "701",
        [
            {"product_id": available_product.id, "quantity": 1},
            {"product_id": unavailable_product.id, "quantity": 1},
        ],
    )
    assert created.status_code == 201

    # Товар пропал из наличия ПОСЛЕ оформления исходного заказа — типичный
    # повод для повтора спустя время.
    await _set_available(unavailable_product.id, False)

    order_id = created.json()["id"]
    resp = await client.post(f"/orders/{order_id}/repeat", headers=_auth(token))
    assert resp.status_code == 200
    body = resp.json()

    assert body["warning"] is not None
    assert body["skipped_items"] == [
        {"product_id": unavailable_product.id, "product_name": unavailable_product.name}
    ]
    assert body["order"]["total"] == 3000

    async with async_session_factory() as session:
        items = (
            await session.execute(
                select(OrderItem).where(OrderItem.order_id == body["order"]["id"])
            )
        ).scalars().all()
        assert len(items) == 1
        assert items[0].product_id == available_product.id


async def test_repeat_all_items_unavailable_is_422(client: AsyncClient):
    _, token = await _make_user("13")
    hotel = await _make_hotel("Hotel13")
    category = await _make_category("Category13")
    product = await _make_product("Product13", category.id)

    created = await _create_order(
        client, token, hotel.name, "801", [{"product_id": product.id, "quantity": 2}]
    )
    order_id = created.json()["id"]

    await _set_available(product.id, False)

    resp = await client.post(f"/orders/{order_id}/repeat", headers=_auth(token))
    assert resp.status_code == 422


async def test_repeat_below_minimum_after_skip_is_422(client: AsyncClient):
    """Один из двух товаров пропал, а оставшийся сам по себе не набирает
    минимальную сумму заказа — повтор недопустим, а не создаётся частично
    ниже порога."""
    _, token = await _make_user("14")
    hotel = await _make_hotel("Hotel14")
    category = await _make_category("Category14")
    cheap_product = await _make_product("ProductCheap14", category.id, price=500)
    expensive_product = await _make_product("ProductExp14", category.id, price=3000)

    created = await _create_order(
        client,
        token,
        hotel.name,
        "901",
        [
            {"product_id": cheap_product.id, "quantity": 1},
            {"product_id": expensive_product.id, "quantity": 1},
        ],
    )
    order_id = created.json()["id"]

    await _set_available(expensive_product.id, False)

    resp = await client.post(f"/orders/{order_id}/repeat", headers=_auth(token))
    assert resp.status_code == 422
