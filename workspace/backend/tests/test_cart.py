"""Корзина: добавление/чтение/изменение/удаление позиций, скрытие
недоступных товаров из выдачи и из total.

Реальный Postgres, тот же контур, что у test_auth.py/test_rbac.py/
test_catalog.py — свой префикс телефона (+70002, чтобы не пересекаться с
+70000/+70001) и свой префикс имён категорий/товаров для очистки.
"""

import pytest_asyncio
from httpx import AsyncClient
from sqlalchemy import delete, select

from app.core.security import create_access_token
from app.db.session import async_session_factory
from app.models.cart_item import CartItem
from app.models.category import Category
from app.models.product import Product
from app.models.role import Role, RoleCode
from app.models.user import User

TEST_PHONE_PREFIX = "+70002"
TEST_PREFIX = "TestCart_"


async def _wipe_cart_test_data() -> None:
    async with async_session_factory() as session:
        user_ids = select(User.id).where(User.phone.like(f"{TEST_PHONE_PREFIX}%"))
        await session.execute(delete(CartItem).where(CartItem.user_id.in_(user_ids)))
        await session.execute(delete(User).where(User.phone.like(f"{TEST_PHONE_PREFIX}%")))

        category_ids = select(Category.id).where(Category.name.like(f"{TEST_PREFIX}%"))
        await session.execute(delete(Product).where(Product.category_id.in_(category_ids)))
        await session.execute(delete(Category).where(Category.name.like(f"{TEST_PREFIX}%")))
        await session.commit()


@pytest_asyncio.fixture(autouse=True)
async def _cleanup_cart_data():
    await _wipe_cart_test_data()
    yield
    await _wipe_cart_test_data()


async def _make_user(suffix: str) -> tuple[User, str]:
    async with async_session_factory() as session:
        result = await session.execute(select(Role).where(Role.code == RoleCode.CLIENT.value))
        role = result.scalar_one()
        user = User(phone=f"{TEST_PHONE_PREFIX}{suffix}", role_id=role.id)
        session.add(user)
        await session.commit()
        await session.refresh(user)
    return user, create_access_token(user.id)


async def _make_category(name: str) -> Category:
    async with async_session_factory() as session:
        category = Category(name=f"{TEST_PREFIX}{name}")
        session.add(category)
        await session.commit()
        await session.refresh(category)
    return category


async def _make_product(
    name: str, category_id: int, *, price: float = 500, is_available: bool = True
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


async def test_get_cart_without_token_is_401(client: AsyncClient):
    resp = await client.get("/cart")
    assert resp.status_code == 401


async def test_add_item_and_get_cart(client: AsyncClient):
    _, token = await _make_user("01")
    category = await _make_category("Category01")
    product = await _make_product("Product01", category.id, price=300)

    add_resp = await client.post(
        "/cart/items", json={"product_id": product.id, "quantity": 2}, headers=_auth(token)
    )
    assert add_resp.status_code == 200
    body = add_resp.json()
    assert len(body["items"]) == 1
    assert body["items"][0]["product"]["id"] == product.id
    assert body["items"][0]["quantity"] == 2
    assert body["items"][0]["line_total"] == 600
    assert body["total"] == 600

    get_resp = await client.get("/cart", headers=_auth(token))
    assert get_resp.status_code == 200
    assert get_resp.json() == body


async def test_add_same_product_twice_increments_quantity(client: AsyncClient):
    _, token = await _make_user("02")
    category = await _make_category("Category02")
    product = await _make_product("Product02", category.id, price=100)

    await client.post(
        "/cart/items", json={"product_id": product.id, "quantity": 1}, headers=_auth(token)
    )
    resp = await client.post(
        "/cart/items", json={"product_id": product.id, "quantity": 3}, headers=_auth(token)
    )
    body = resp.json()
    assert len(body["items"]) == 1
    assert body["items"][0]["quantity"] == 4
    assert body["total"] == 400


async def test_add_unavailable_product_is_404(client: AsyncClient):
    _, token = await _make_user("03")
    category = await _make_category("Category03")
    product = await _make_product("Product03", category.id, is_available=False)

    resp = await client.post(
        "/cart/items", json={"product_id": product.id, "quantity": 1}, headers=_auth(token)
    )
    assert resp.status_code == 404


async def test_add_unknown_product_is_404(client: AsyncClient):
    _, token = await _make_user("04")
    resp = await client.post(
        "/cart/items", json={"product_id": 999999999, "quantity": 1}, headers=_auth(token)
    )
    assert resp.status_code == 404


async def test_update_item_quantity(client: AsyncClient):
    _, token = await _make_user("05")
    category = await _make_category("Category05")
    product = await _make_product("Product05", category.id, price=200)

    add_resp = await client.post(
        "/cart/items", json={"product_id": product.id, "quantity": 1}, headers=_auth(token)
    )
    item_id = add_resp.json()["items"][0]["id"]

    resp = await client.put(
        f"/cart/items/{item_id}", json={"quantity": 5}, headers=_auth(token)
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["items"][0]["quantity"] == 5
    assert body["total"] == 1000


async def test_update_item_quantity_zero_is_422(client: AsyncClient):
    _, token = await _make_user("06")
    category = await _make_category("Category06")
    product = await _make_product("Product06", category.id)

    add_resp = await client.post(
        "/cart/items", json={"product_id": product.id, "quantity": 1}, headers=_auth(token)
    )
    item_id = add_resp.json()["items"][0]["id"]

    resp = await client.put(
        f"/cart/items/{item_id}", json={"quantity": 0}, headers=_auth(token)
    )
    assert resp.status_code == 422


async def test_delete_item_removes_it(client: AsyncClient):
    _, token = await _make_user("07")
    category = await _make_category("Category07")
    product_a = await _make_product("Product07a", category.id, price=100)
    product_b = await _make_product("Product07b", category.id, price=50)

    resp_a = await client.post(
        "/cart/items", json={"product_id": product_a.id, "quantity": 1}, headers=_auth(token)
    )
    await client.post(
        "/cart/items", json={"product_id": product_b.id, "quantity": 1}, headers=_auth(token)
    )
    item_a_id = resp_a.json()["items"][0]["id"]

    resp = await client.delete(f"/cart/items/{item_a_id}", headers=_auth(token))
    assert resp.status_code == 200
    body = resp.json()
    assert len(body["items"]) == 1
    assert body["items"][0]["product"]["id"] == product_b.id
    assert body["total"] == 50


async def test_clear_cart(client: AsyncClient):
    _, token = await _make_user("08")
    category = await _make_category("Category08")
    product = await _make_product("Product08", category.id)

    await client.post(
        "/cart/items", json={"product_id": product.id, "quantity": 1}, headers=_auth(token)
    )
    resp = await client.delete("/cart", headers=_auth(token))
    assert resp.status_code == 200
    body = resp.json()
    assert body["items"] == []
    assert body["total"] == 0

    get_resp = await client.get("/cart", headers=_auth(token))
    assert get_resp.json()["items"] == []


async def test_unavailable_product_excluded_from_cart_and_total(client: AsyncClient):
    _, token = await _make_user("09")
    category = await _make_category("Category09")
    available = await _make_product("Product09a", category.id, price=100)
    will_go_unavailable = await _make_product("Product09b", category.id, price=200)

    await client.post(
        "/cart/items", json={"product_id": available.id, "quantity": 1}, headers=_auth(token)
    )
    await client.post(
        "/cart/items",
        json={"product_id": will_go_unavailable.id, "quantity": 1},
        headers=_auth(token),
    )

    await _set_available(will_go_unavailable.id, False)

    resp = await client.get("/cart", headers=_auth(token))
    body = resp.json()
    ids = [item["product"]["id"] for item in body["items"]]
    assert available.id in ids
    assert will_go_unavailable.id not in ids
    assert body["total"] == 100


async def test_cannot_modify_other_users_item(client: AsyncClient):
    _, token_a = await _make_user("10")
    _, token_b = await _make_user("11")
    category = await _make_category("Category10")
    product = await _make_product("Product10", category.id)

    add_resp = await client.post(
        "/cart/items", json={"product_id": product.id, "quantity": 1}, headers=_auth(token_a)
    )
    item_id = add_resp.json()["items"][0]["id"]

    put_resp = await client.put(
        f"/cart/items/{item_id}", json={"quantity": 2}, headers=_auth(token_b)
    )
    assert put_resp.status_code == 404

    delete_resp = await client.delete(f"/cart/items/{item_id}", headers=_auth(token_b))
    assert delete_resp.status_code == 404


async def test_update_unknown_item_is_404(client: AsyncClient):
    _, token = await _make_user("12")
    resp = await client.put(
        "/cart/items/999999999", json={"quantity": 2}, headers=_auth(token)
    )
    assert resp.status_code == 404


async def test_carts_are_isolated_per_user(client: AsyncClient):
    _, token_a = await _make_user("13")
    _, token_b = await _make_user("14")
    category = await _make_category("Category13")
    product = await _make_product("Product13", category.id, price=100)

    await client.post(
        "/cart/items", json={"product_id": product.id, "quantity": 1}, headers=_auth(token_a)
    )

    resp = await client.get("/cart", headers=_auth(token_b))
    assert resp.status_code == 200
    assert resp.json()["items"] == []
