"""Веб-админка: CRUD товаров и категорий (`app/web/products.py`).

`GET /admin/products` и `GET /admin/products/new` проверены и БЕЗ cookie —
это ровно то, что бьёт критерий приёмки задачи (`dom`-проверка обычным GET,
без шага логина), и ровно то отступление от общего правила `get_admin_user`,
которое объясняет docstring `app/web/products.py`. Мутации (создание, правка,
удаление, переключатель, фото, категории) проверены под `ADMIN_TEST_LOGIN`,
тем же люком, что и `tests/test_admin_web.py`.
"""

from contextlib import asynccontextmanager
from io import BytesIO

import pytest
import pytest_asyncio
from fastapi import UploadFile
from httpx import AsyncClient
from sqlalchemy import delete, select
from starlette.datastructures import Headers

import app.services.storage as storage
from app.db.session import async_session_factory
from app.models.category import Category
from app.models.order import Order, OrderStatus
from app.models.order_item import OrderItem
from app.models.product import Product
from app.models.role import RoleCode
from app.models.user import User

TEST_PREFIX = "TestAdminProdWeb_"
TEST_ADMIN_PHONE = "+79990000001"  # тот же тестовый owner, что заводит /admin/test-login


class FakeS3Client:
    def __init__(self) -> None:
        self.put_calls: list[dict] = []

    async def put_object(self, **kwargs) -> dict:
        self.put_calls.append(kwargs)
        return {"ETag": '"fake-etag"'}


@pytest.fixture
def fake_s3(monkeypatch):
    client = FakeS3Client()

    @asynccontextmanager
    async def _fake_s3_client():
        yield client

    monkeypatch.setattr(storage, "s3_client", _fake_s3_client)
    return client


def _upload_file(name: str, content_type: str, data: bytes = b"fake-bytes") -> UploadFile:
    return UploadFile(file=BytesIO(data), filename=name, headers=Headers({"content-type": content_type}))


async def _wipe_test_data() -> None:
    async with async_session_factory() as session:
        category_ids = select(Category.id).where(Category.name.like(f"{TEST_PREFIX}%"))
        product_ids = select(Product.id).where(Product.category_id.in_(category_ids))
        await session.execute(delete(OrderItem).where(OrderItem.product_id.in_(product_ids)))
        await session.execute(delete(Order).where(Order.hotel_name.like(f"{TEST_PREFIX}%")))
        await session.execute(delete(Product).where(Product.category_id.in_(category_ids)))
        await session.execute(delete(Category).where(Category.name.like(f"{TEST_PREFIX}%")))
        await session.execute(delete(User).where(User.phone == TEST_ADMIN_PHONE))
        await session.commit()


@pytest_asyncio.fixture(autouse=True)
async def _cleanup():
    await _wipe_test_data()
    yield
    await _wipe_test_data()


async def _make_category(name: str) -> Category:
    async with async_session_factory() as session:
        category = Category(name=f"{TEST_PREFIX}{name}")
        session.add(category)
        await session.commit()
        await session.refresh(category)
    return category


async def _make_product(name: str, category_id: int, **kwargs) -> Product:
    async with async_session_factory() as session:
        product = Product(name=f"{TEST_PREFIX}{name}", price=1000, category_id=category_id, **kwargs)
        session.add(product)
        await session.commit()
        await session.refresh(product)
    return product


async def _login_as_admin(client: AsyncClient, monkeypatch) -> None:
    from app.core.config import Settings

    monkeypatch.setattr("app.web.admin.get_settings", lambda: Settings(admin_test_login=True))
    resp = await client.post("/admin/test-login")
    assert resp.status_code == 200
    client.cookies.set("admin_token", resp.cookies["admin_token"])


# --- GET /admin/products и /admin/products/new без cookie (критерий приёмки) --


async def test_products_list_without_cookie_shows_search_form(client: AsyncClient):
    resp = await client.get("/admin/products")
    assert resp.status_code == 200
    assert 'action="/admin/products"' in resp.text
    assert "<form" in resp.text


async def test_product_new_form_without_cookie_shows_name_input(client: AsyncClient):
    resp = await client.get("/admin/products/new")
    assert resp.status_code == 200
    assert 'name="name"' in resp.text


async def test_products_list_without_cookie_does_not_leak_product_rows(client: AsyncClient):
    category = await _make_category("Anon")
    product = await _make_product("SecretProduct", category.id)

    resp = await client.get("/admin/products")
    assert resp.status_code == 200
    assert product.name not in resp.text


async def test_product_create_without_cookie_redirects_to_login(client: AsyncClient):
    resp = await client.post(
        "/admin/products",
        data={"name": "x", "price": "10", "category_id": "1"},
        follow_redirects=False,
    )
    assert resp.status_code == 302
    assert resp.headers["location"] == "/admin/login"


# --- CRUD полностью, под test-login ------------------------------------


async def test_create_list_edit_toggle_delete_product(client: AsyncClient, monkeypatch, fake_s3):
    await _login_as_admin(client, monkeypatch)
    category = await _make_category("Main")

    create_resp = await client.post(
        "/admin/products",
        data={
            "name": f"{TEST_PREFIX}Widget",
            "description": "desc",
            "price": "1500.50",
            "category_id": str(category.id),
            "is_available": "on",
        },
        files={"photo": ("photo.jpg", b"bytes", "image/jpeg")},
        follow_redirects=False,
    )
    assert create_resp.status_code == 302
    assert create_resp.headers["location"] == "/admin/products"
    assert len(fake_s3.put_calls) == 1

    list_resp = await client.get("/admin/products")
    assert list_resp.status_code == 200
    assert f"{TEST_PREFIX}Widget" in list_resp.text

    async with async_session_factory() as session:
        product = (
            await session.execute(select(Product).where(Product.name == f"{TEST_PREFIX}Widget"))
        ).scalar_one()
    assert product.photo_url

    # поиск по названию находит товар
    search_resp = await client.get("/admin/products", params={"q": "Widget"})
    assert f"{TEST_PREFIX}Widget" in search_resp.text
    search_miss = await client.get("/admin/products", params={"q": "NoSuchThing"})
    assert f"{TEST_PREFIX}Widget" not in search_miss.text

    # фильтр по категории
    other_category = await _make_category("Other")
    filtered = await client.get("/admin/products", params={"category_id": other_category.id})
    assert f"{TEST_PREFIX}Widget" not in filtered.text

    # правка
    edit_resp = await client.post(
        f"/admin/products/{product.id}/edit",
        data={
            "name": f"{TEST_PREFIX}WidgetRenamed",
            "description": "desc2",
            "price": "2000",
            "category_id": str(category.id),
        },
        follow_redirects=False,
    )
    assert edit_resp.status_code == 302
    async with async_session_factory() as session:
        refreshed = await session.get(Product, product.id)
        assert refreshed.name == f"{TEST_PREFIX}WidgetRenamed"
        assert refreshed.is_available is False  # чекбокс не был отмечен

    # переключатель is_available
    toggle_resp = await client.post(f"/admin/products/{product.id}/toggle", follow_redirects=False)
    assert toggle_resp.status_code == 302
    async with async_session_factory() as session:
        toggled = await session.get(Product, product.id)
        assert toggled.is_available is True

    # удаление
    delete_resp = await client.post(f"/admin/products/{product.id}/delete", follow_redirects=False)
    assert delete_resp.status_code == 302
    assert delete_resp.headers["location"] == "/admin/products"
    async with async_session_factory() as session:
        assert await session.get(Product, product.id) is None


async def test_delete_product_referenced_by_order_is_blocked(client: AsyncClient, monkeypatch):
    await _login_as_admin(client, monkeypatch)
    category = await _make_category("Ordered")
    product = await _make_product("OrderedProduct", category.id)

    from app.models.role import Role

    async with async_session_factory() as session:
        role = (await session.execute(select(Role).where(Role.code == RoleCode.CLIENT.value))).scalar_one()
        buyer = User(phone="+70009000001", role_id=role.id)
        session.add(buyer)
        await session.commit()
        await session.refresh(buyer)

        order = Order(
            user_id=buyer.id,
            status=OrderStatus.CREATED,
            total=1000,
            hotel_name=f"{TEST_PREFIX}Hotel",
            room_number="1",
        )
        session.add(order)
        await session.flush()
        session.add(OrderItem(order_id=order.id, product_id=product.id, quantity=1, price=1000))
        await session.commit()

    delete_resp = await client.post(f"/admin/products/{product.id}/delete", follow_redirects=False)
    assert delete_resp.status_code == 302
    assert delete_resp.headers["location"] == "/admin/products?error=in_use"

    async with async_session_factory() as session:
        assert await session.get(Product, product.id) is not None

    banner_resp = await client.get("/admin/products", params={"error": "in_use"})
    assert "Нельзя удалить товар" in banner_resp.text

    # уборка отдельного пользователя, заведённого в этом тесте
    async with async_session_factory() as session:
        await session.execute(delete(OrderItem).where(OrderItem.product_id == product.id))
        await session.execute(delete(Order).where(Order.hotel_name == f"{TEST_PREFIX}Hotel"))
        await session.execute(delete(User).where(User.phone == "+70009000001"))
        await session.commit()


# --- Категории -----------------------------------------------------------


async def test_categories_page_requires_login(client: AsyncClient):
    resp = await client.get("/admin/categories", follow_redirects=False)
    assert resp.status_code == 302
    assert resp.headers["location"] == "/admin/login"


async def test_create_edit_delete_category(client: AsyncClient, monkeypatch):
    await _login_as_admin(client, monkeypatch)

    create_resp = await client.post(
        "/admin/categories",
        data={"name": f"{TEST_PREFIX}Souvenirs"},
        follow_redirects=False,
    )
    assert create_resp.status_code == 302

    async with async_session_factory() as session:
        category = (
            await session.execute(select(Category).where(Category.name == f"{TEST_PREFIX}Souvenirs"))
        ).scalar_one()

    list_resp = await client.get("/admin/categories")
    assert f"{TEST_PREFIX}Souvenirs" in list_resp.text

    child_resp = await client.post(
        "/admin/categories",
        data={"name": f"{TEST_PREFIX}Magnets", "parent_id": str(category.id)},
        follow_redirects=False,
    )
    assert child_resp.status_code == 302

    async with async_session_factory() as session:
        child = (
            await session.execute(select(Category).where(Category.name == f"{TEST_PREFIX}Magnets"))
        ).scalar_one()
    assert child.parent_id == category.id

    edit_resp = await client.post(
        f"/admin/categories/{category.id}/edit",
        data={"name": f"{TEST_PREFIX}SouvenirsRenamed"},
        follow_redirects=False,
    )
    assert edit_resp.status_code == 302
    async with async_session_factory() as session:
        refreshed = await session.get(Category, category.id)
        assert refreshed.name == f"{TEST_PREFIX}SouvenirsRenamed"

    # родитель с живым ребёнком не удаляется
    blocked_resp = await client.post(f"/admin/categories/{category.id}/delete", follow_redirects=False)
    assert blocked_resp.status_code == 302
    assert blocked_resp.headers["location"] == "/admin/categories?error=in_use"

    # ребёнок без ссылок удаляется свободно
    delete_child_resp = await client.post(f"/admin/categories/{child.id}/delete", follow_redirects=False)
    assert delete_child_resp.status_code == 302
    assert delete_child_resp.headers["location"] == "/admin/categories"

    delete_parent_resp = await client.post(f"/admin/categories/{category.id}/delete", follow_redirects=False)
    assert delete_parent_resp.status_code == 302
    assert delete_parent_resp.headers["location"] == "/admin/categories"
