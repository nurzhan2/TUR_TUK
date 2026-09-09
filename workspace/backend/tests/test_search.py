"""Поиск товаров по ключевым словам: GET /catalog/products?search=...

ILIKE по name и description, регистронезависимо. Недоступные товары
(is_available=False) в выдачу поиска не попадают — то же правило, что
и у обычного листинга каталога.
"""

import pytest_asyncio
from httpx import AsyncClient
from sqlalchemy import delete, select

from app.db.session import async_session_factory
from app.models.category import Category
from app.models.product import Product

TEST_PREFIX = "TestSearch_"


async def _wipe_search_test_data() -> None:
    async with async_session_factory() as session:
        category_ids = select(Category.id).where(Category.name.like(f"{TEST_PREFIX}%"))
        await session.execute(delete(Product).where(Product.category_id.in_(category_ids)))
        await session.execute(delete(Category).where(Category.name.like(f"{TEST_PREFIX}%")))
        await session.commit()


@pytest_asyncio.fixture(autouse=True)
async def _cleanup_search_data():
    await _wipe_search_test_data()
    yield
    await _wipe_search_test_data()


async def _make_category(name: str) -> Category:
    async with async_session_factory() as session:
        category = Category(name=f"{TEST_PREFIX}{name}")
        session.add(category)
        await session.commit()
        await session.refresh(category)
    return category


async def _make_product(
    name: str,
    category_id: int,
    *,
    description: str = "описание",
    is_available: bool = True,
) -> Product:
    async with async_session_factory() as session:
        product = Product(
            name=f"{TEST_PREFIX}{name}",
            description=description,
            price=500,
            category_id=category_id,
            is_available=is_available,
            photo_url="https://example.com/photo.jpg",
        )
        session.add(product)
        await session.commit()
        await session.refresh(product)
    return product


async def test_search_returns_empty_for_unknown(client: AsyncClient) -> None:
    category = await _make_category("Сувениры")
    await _make_product("Магнит", category.id)

    response = await client.get(
        "/catalog/products", params={"search": "НесуществующийТоварXYZ"}
    )
    assert response.status_code == 200
    body = response.json()
    assert body["items"] == []
    assert body["total"] == 0


async def test_search_finds_product_by_name_substring(client: AsyncClient) -> None:
    category = await _make_category("Косметика")
    matching = await _make_product("Крем для рук", category.id)
    await _make_product("Магнит", category.id)

    response = await client.get("/catalog/products", params={"search": "рем для"})
    assert response.status_code == 200
    body = response.json()

    ids = [item["id"] for item in body["items"]]
    assert ids == [matching.id]
    assert body["total"] == 1


async def test_search_matches_description(client: AsyncClient) -> None:
    category = await _make_category("Продукты")
    matching = await _make_product(
        "Шоколад", category.id, description="Турецкий шоколад с фундуком"
    )
    await _make_product("Печенье", category.id, description="Хрустящее печенье")

    response = await client.get("/catalog/products", params={"search": "фундук"})
    assert response.status_code == 200
    body = response.json()

    ids = [item["id"] for item in body["items"]]
    assert ids == [matching.id]


async def test_search_hides_unavailable_products(client: AsyncClient) -> None:
    category = await _make_category("Скрытые")
    await _make_product("СнятыйСПродажи", category.id, is_available=False)

    response = await client.get("/catalog/products", params={"search": "Снятый"})
    assert response.status_code == 200
    body = response.json()
    assert body["items"] == []
