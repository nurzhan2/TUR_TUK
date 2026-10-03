"""POST /orders: минимальная сумма заказа, зона доставки по списку отелей,
единая цена товара (не зависит от hotel_name), применение промокода.
GET /orders/{id} уже был реализован раньше (test_rbac.py покрывает владение);
здесь — сквозной сценарий «создал → получил тем же id».

Реальный Postgres, тот же контур, что у остальных файлов — свой префикс
телефона (+70006, свободен: +70000/+70001/+70002/+70003/+70004/+70005 заняты
другими файлами) и свой префикс имён отелей/категорий/промокодов для очистки.
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
from app.models.promo_code import PromoCode
from app.models.role import Role, RoleCode
from app.models.user import User

TEST_PHONE_PREFIX = "+70006"
TEST_PREFIX = "TestOrders_"

# Дешёвый товар — заведомо ниже минимальной суммы заказа (3000 ₽), дорогой —
# позволяет одной позицией уверенно перевалить порог.
CHEAP_PRICE = 500
EXPENSIVE_PRICE = 2000


async def _wipe_orders_test_data() -> None:
    async with async_session_factory() as session:
        user_ids = select(User.id).where(User.phone.like(f"{TEST_PHONE_PREFIX}%"))
        order_ids = select(Order.id).where(Order.user_id.in_(user_ids))
        await session.execute(delete(OrderItem).where(OrderItem.order_id.in_(order_ids)))
        await session.execute(delete(Order).where(Order.user_id.in_(user_ids)))
        await session.execute(delete(User).where(User.phone.like(f"{TEST_PHONE_PREFIX}%")))

        category_ids = select(Category.id).where(Category.name.like(f"{TEST_PREFIX}%"))
        await session.execute(delete(Product).where(Product.category_id.in_(category_ids)))
        await session.execute(delete(Category).where(Category.name.like(f"{TEST_PREFIX}%")))

        await session.execute(delete(Hotel).where(Hotel.name.like(f"{TEST_PREFIX}%")))
        await session.execute(delete(PromoCode).where(PromoCode.code.like(f"{TEST_PREFIX}%")))
        await session.commit()


@pytest_asyncio.fixture(autouse=True)
async def _cleanup_orders_data():
    await _wipe_orders_test_data()
    yield
    await _wipe_orders_test_data()


async def _make_user(suffix: str) -> tuple[User, str]:
    async with async_session_factory() as session:
        result = await session.execute(select(Role).where(Role.code == RoleCode.CLIENT.value))
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
    name: str, category_id: int, *, price: float = CHEAP_PRICE, is_available: bool = True
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


async def _make_promo(
    suffix: str, *, discount_percent: float | None = None, discount_amount: float | None = None
) -> PromoCode:
    async with async_session_factory() as session:
        promo = PromoCode(
            code=f"{TEST_PREFIX}{suffix}",
            discount_percent=discount_percent,
            discount_amount=discount_amount,
        )
        session.add(promo)
        await session.commit()
        await session.refresh(promo)
    return promo


def _auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


async def test_create_order_without_token_is_401(client: AsyncClient):
    resp = await client.post("/orders", json={"hotel_name": "x", "room_number": "1", "items": []})
    assert resp.status_code == 401


async def test_order_below_minimum_rejected(client: AsyncClient):
    _, token = await _make_user("01")
    hotel = await _make_hotel("Hotel01")
    category = await _make_category("Category01")
    product = await _make_product("Product01", category.id, price=CHEAP_PRICE)

    resp = await client.post(
        "/orders",
        json={
            "hotel_name": hotel.name,
            "room_number": "101",
            "items": [{"product_id": product.id, "quantity": 1}],
        },
        headers=_auth(token),
    )
    assert resp.status_code == 422

    async with async_session_factory() as session:
        count = (
            await session.execute(select(Order).where(Order.hotel_name == hotel.name))
        ).scalars().all()
        assert count == []


async def test_order_at_minimum_is_accepted(client: AsyncClient):
    _, token = await _make_user("02")
    hotel = await _make_hotel("Hotel02")
    category = await _make_category("Category02")
    product = await _make_product("Product02", category.id, price=3000)

    resp = await client.post(
        "/orders",
        json={
            "hotel_name": hotel.name,
            "room_number": "102",
            "items": [{"product_id": product.id, "quantity": 1}],
        },
        headers=_auth(token),
    )
    assert resp.status_code == 201
    # 3000 товаров + 300 доставки: бесплатная — только от 5000 (настройки по умолчанию)
    assert resp.json()["subtotal"] == 3000
    assert resp.json()["delivery_fee"] == 300
    assert resp.json()["total"] == 3300


async def test_unknown_hotel_rejected(client: AsyncClient):
    _, token = await _make_user("03")
    category = await _make_category("Category03")
    product = await _make_product("Product03", category.id, price=EXPENSIVE_PRICE)

    resp = await client.post(
        "/orders",
        json={
            "hotel_name": f"{TEST_PREFIX}NoSuchHotel",
            "room_number": "103",
            "items": [{"product_id": product.id, "quantity": 2}],
        },
        headers=_auth(token),
    )
    assert resp.status_code == 422


async def test_hotel_name_is_case_insensitive(client: AsyncClient):
    _, token = await _make_user("04")
    hotel = await _make_hotel("Hotel04")
    category = await _make_category("Category04")
    product = await _make_product("Product04", category.id, price=EXPENSIVE_PRICE)

    resp = await client.post(
        "/orders",
        json={
            "hotel_name": hotel.name.upper(),
            "room_number": "104",
            "items": [{"product_id": product.id, "quantity": 2}],
        },
        headers=_auth(token),
    )
    assert resp.status_code == 201
    assert resp.json()["hotel_name"] == hotel.name


async def test_price_uniform_across_hotels(client: AsyncClient):
    """«Единая цена товара — не зависит от hotel_name» (бриф, curated) —
    один и тот же состав заказа даёт один и тот же total в разных отелях."""
    _, token = await _make_user("05")
    hotel_a = await _make_hotel("Hotel05A")
    hotel_b = await _make_hotel("Hotel05B")
    category = await _make_category("Category05")
    product = await _make_product("Product05", category.id, price=EXPENSIVE_PRICE)

    resp_a = await client.post(
        "/orders",
        json={
            "hotel_name": hotel_a.name,
            "room_number": "105",
            "items": [{"product_id": product.id, "quantity": 2}],
        },
        headers=_auth(token),
    )
    resp_b = await client.post(
        "/orders",
        json={
            "hotel_name": hotel_b.name,
            "room_number": "105",
            "items": [{"product_id": product.id, "quantity": 2}],
        },
        headers=_auth(token),
    )
    assert resp_a.status_code == 201
    assert resp_b.status_code == 201
    assert resp_a.json()["total"] == resp_b.json()["total"] == 4300  # 4000 + доставка 300


async def test_create_order_unknown_product_is_404(client: AsyncClient):
    _, token = await _make_user("06")
    hotel = await _make_hotel("Hotel06")

    resp = await client.post(
        "/orders",
        json={
            "hotel_name": hotel.name,
            "room_number": "106",
            "items": [{"product_id": 999999999, "quantity": 1}],
        },
        headers=_auth(token),
    )
    assert resp.status_code == 404


async def test_create_order_unavailable_product_is_404(client: AsyncClient):
    _, token = await _make_user("07")
    hotel = await _make_hotel("Hotel07")
    category = await _make_category("Category07")
    product = await _make_product(
        "Product07", category.id, price=EXPENSIVE_PRICE, is_available=False
    )

    resp = await client.post(
        "/orders",
        json={
            "hotel_name": hotel.name,
            "room_number": "107",
            "items": [{"product_id": product.id, "quantity": 2}],
        },
        headers=_auth(token),
    )
    assert resp.status_code == 404


async def test_create_order_empty_items_is_422(client: AsyncClient):
    _, token = await _make_user("08")
    hotel = await _make_hotel("Hotel08")

    resp = await client.post(
        "/orders",
        json={"hotel_name": hotel.name, "room_number": "108", "items": []},
        headers=_auth(token),
    )
    assert resp.status_code == 422


async def test_create_order_status_is_pending(client: AsyncClient):
    _, token = await _make_user("09")
    hotel = await _make_hotel("Hotel09")
    category = await _make_category("Category09")
    product = await _make_product("Product09", category.id, price=EXPENSIVE_PRICE)

    resp = await client.post(
        "/orders",
        json={
            "hotel_name": hotel.name,
            "room_number": "109",
            "items": [{"product_id": product.id, "quantity": 2}],
        },
        headers=_auth(token),
    )
    assert resp.status_code == 201
    # OrderStatus не содержит буквального значения "pending" — заказ до
    # принятия курьером висит в "created" (см. docs/DECISIONS.md), это то же
    # состояние, что и умолчание модели/колонки.
    assert resp.json()["status"] == "created"


async def test_create_order_applies_percent_promo(client: AsyncClient):
    _, token = await _make_user("10")
    hotel = await _make_hotel("Hotel10")
    category = await _make_category("Category10")
    product = await _make_product("Product10", category.id, price=EXPENSIVE_PRICE)
    promo = await _make_promo("PROMO10", discount_percent=10)

    resp = await client.post(
        "/orders",
        json={
            "hotel_name": hotel.name,
            "room_number": "110",
            "items": [{"product_id": product.id, "quantity": 2}],
            "promo_code": promo.code,
        },
        headers=_auth(token),
    )
    assert resp.status_code == 201
    # subtotal = 4000, скидка 10% = 400
    assert resp.json()["discount"] == 400
    # + 300 доставки: бесплатная — от 5000 по сумме товаров
    assert resp.json()["total"] == 3900


async def test_create_order_increments_promo_used_count(client: AsyncClient):
    _, token = await _make_user("11")
    hotel = await _make_hotel("Hotel11")
    category = await _make_category("Category11")
    product = await _make_product("Product11", category.id, price=EXPENSIVE_PRICE)
    promo = await _make_promo("PROMO11", discount_amount=500)

    resp = await client.post(
        "/orders",
        json={
            "hotel_name": hotel.name,
            "room_number": "111",
            "items": [{"product_id": product.id, "quantity": 2}],
            "promo_code": promo.code,
        },
        headers=_auth(token),
    )
    assert resp.status_code == 201

    async with async_session_factory() as session:
        refreshed = await session.get(PromoCode, promo.id)
        assert refreshed.used_count == 1


async def test_create_order_unknown_promo_is_404(client: AsyncClient):
    _, token = await _make_user("12")
    hotel = await _make_hotel("Hotel12")
    category = await _make_category("Category12")
    product = await _make_product("Product12", category.id, price=EXPENSIVE_PRICE)

    resp = await client.post(
        "/orders",
        json={
            "hotel_name": hotel.name,
            "room_number": "112",
            "items": [{"product_id": product.id, "quantity": 2}],
            "promo_code": f"{TEST_PREFIX}NoSuchPromo",
        },
        headers=_auth(token),
    )
    assert resp.status_code == 404


async def test_promo_cannot_bypass_minimum_total(client: AsyncClient):
    """Порог сверяется с суммой ДО скидки — промокод не даёт провести заказ
    ниже 3000 ₽, набранных товарами."""
    _, token = await _make_user("13")
    hotel = await _make_hotel("Hotel13")
    category = await _make_category("Category13")
    product = await _make_product("Product13", category.id, price=CHEAP_PRICE)
    promo = await _make_promo("PROMO13", discount_percent=90)

    resp = await client.post(
        "/orders",
        json={
            "hotel_name": hotel.name,
            "room_number": "113",
            "items": [{"product_id": product.id, "quantity": 1}],
            "promo_code": promo.code,
        },
        headers=_auth(token),
    )
    assert resp.status_code == 422


async def test_get_order_by_id_after_creation(client: AsyncClient):
    _, token = await _make_user("14")
    hotel = await _make_hotel("Hotel14")
    category = await _make_category("Category14")
    product = await _make_product("Product14", category.id, price=EXPENSIVE_PRICE)

    create_resp = await client.post(
        "/orders",
        json={
            "hotel_name": hotel.name,
            "room_number": "114",
            "items": [{"product_id": product.id, "quantity": 2}],
        },
        headers=_auth(token),
    )
    order_id = create_resp.json()["id"]

    get_resp = await client.get(f"/orders/{order_id}", headers=_auth(token))
    assert get_resp.status_code == 200
    assert get_resp.json() == create_resp.json()


async def test_order_items_persisted_with_snapshot_price(client: AsyncClient):
    _, token = await _make_user("15")
    hotel = await _make_hotel("Hotel15")
    category = await _make_category("Category15")
    product = await _make_product("Product15", category.id, price=EXPENSIVE_PRICE)

    create_resp = await client.post(
        "/orders",
        json={
            "hotel_name": hotel.name,
            "room_number": "115",
            "items": [{"product_id": product.id, "quantity": 3}],
        },
        headers=_auth(token),
    )
    order_id = create_resp.json()["id"]

    async with async_session_factory() as session:
        items = (
            await session.execute(select(OrderItem).where(OrderItem.order_id == order_id))
        ).scalars().all()
        assert len(items) == 1
        assert items[0].product_id == product.id
        assert items[0].quantity == 3
        assert float(items[0].price) == EXPENSIVE_PRICE
