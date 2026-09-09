"""Каталог: дерево категорий, пагинация товаров, скрытие недоступных.

У каталога нет своего write-API (добавление товаров — задача админки),
поэтому фикстуры заводятся напрямую через `async_session_factory`, как и
заказы в `test_rbac.py`.
"""

import pytest_asyncio
from httpx import AsyncClient
from sqlalchemy import delete, select

from app.db.session import async_session_factory
from app.models.category import Category
from app.models.product import Product

# Отличает тестовые данные от чужих в общей (не in-memory) БД — по нему
# чистим за собой, как и остальные test_*.py в этом каталоге.
TEST_PREFIX = "TestCatalog_"


async def _wipe_catalog_test_data() -> None:
    async with async_session_factory() as session:
        category_ids = select(Category.id).where(Category.name.like(f"{TEST_PREFIX}%"))
        await session.execute(delete(Product).where(Product.category_id.in_(category_ids)))
        # Категории самоссылаются через parent_id (ребёнок создан позже
        # родителя => больший id) — удаляем от листьев к корню по убыванию id,
        # иначе DELETE родителя упадёт на FK, пока жив ребёнок.
        result = await session.execute(
            select(Category.id)
            .where(Category.name.like(f"{TEST_PREFIX}%"))
            .order_by(Category.id.desc())
        )
        for category_id in result.scalars().all():
            await session.execute(delete(Category).where(Category.id == category_id))
        await session.commit()


@pytest_asyncio.fixture(autouse=True)
async def _cleanup_catalog_data():
    # И до, и после — если предыдущий прогон упал посередине, следующий не
    # должен наследовать его мусор (тот же приём, что в test_rbac.py).
    await _wipe_catalog_test_data()
    yield
    await _wipe_catalog_test_data()


async def _make_category(name: str, parent_id: int | None = None) -> Category:
    async with async_session_factory() as session:
        category = Category(name=f"{TEST_PREFIX}{name}", parent_id=parent_id)
        session.add(category)
        await session.commit()
        await session.refresh(category)
    return category


async def _make_product(
    name: str,
    category_id: int,
    *,
    price: float = 500,
    is_available: bool = True,
) -> Product:
    async with async_session_factory() as session:
        product = Product(
            name=f"{TEST_PREFIX}{name}",
            description="описание",
            price=price,
            category_id=category_id,
            is_available=is_available,
            photo_url="https://example.com/photo.jpg",
        )
        session.add(product)
        await session.commit()
        await session.refresh(product)
    return product


async def test_categories_tree_nests_children(client: AsyncClient) -> None:
    parent = await _make_category("Сувениры")
    child = await _make_category("Магниты", parent_id=parent.id)

    response = await client.get("/catalog/categories")
    assert response.status_code == 200
    tree = response.json()

    parent_node = next(node for node in tree if node["id"] == parent.id)
    assert parent_node["name"] == parent.name
    child_ids = [c["id"] for c in parent_node["children"]]
    assert child.id in child_ids
    assert parent_node["children"][0]["name"] == child.name


async def test_products_endpoint_hides_unavailable(client: AsyncClient) -> None:
    category = await _make_category("Косметика")
    available = await _make_product("Крем", category.id, is_available=True)
    await _make_product("СнятСПродажи", category.id, is_available=False)

    response = await client.get(f"/catalog/products?category_id={category.id}")
    assert response.status_code == 200
    body = response.json()

    ids = [item["id"] for item in body["items"]]
    assert ids == [available.id]
    assert body["total"] == 1
    assert all(item["is_available"] for item in body["items"])


async def test_products_endpoint_paginates(client: AsyncClient) -> None:
    category = await _make_category("Продукты")
    products = [await _make_product(f"Товар{i}", category.id) for i in range(3)]

    first_page = await client.get(
        f"/catalog/products?category_id={category.id}&page=1&limit=2"
    )
    assert first_page.status_code == 200
    first_body = first_page.json()
    assert first_body["page"] == 1
    assert first_body["limit"] == 2
    assert first_body["total"] == 3
    assert len(first_body["items"]) == 2

    second_page = await client.get(
        f"/catalog/products?category_id={category.id}&page=2&limit=2"
    )
    second_body = second_page.json()
    assert second_body["total"] == 3
    assert len(second_body["items"]) == 1

    seen_ids = {item["id"] for item in first_body["items"] + second_body["items"]}
    assert seen_ids == {p.id for p in products}


async def test_products_endpoint_filters_by_category(client: AsyncClient) -> None:
    cat_a = await _make_category("КатегорияA")
    cat_b = await _make_category("КатегорияB")
    product_a = await _make_product("ТоварA", cat_a.id)
    await _make_product("ТоварB", cat_b.id)

    response = await client.get(f"/catalog/products?category_id={cat_a.id}")
    body = response.json()
    assert [item["id"] for item in body["items"]] == [product_a.id]


async def test_product_detail_returns_fields(client: AsyncClient) -> None:
    category = await _make_category("Сувениры2")
    product = await _make_product("Магнит", category.id, price=350)

    response = await client.get(f"/catalog/products/{product.id}")
    assert response.status_code == 200
    body = response.json()
    assert body["id"] == product.id
    assert body["name"] == product.name
    assert float(body["price"]) == 350
    assert body["is_available"] is True
    assert body["photo_url"] == product.photo_url


async def test_product_detail_hides_unavailable(client: AsyncClient) -> None:
    category = await _make_category("Сувениры3")
    product = await _make_product("Скрытый", category.id, is_available=False)

    response = await client.get(f"/catalog/products/{product.id}")
    assert response.status_code == 404


async def test_product_detail_missing_returns_404(client: AsyncClient) -> None:
    response = await client.get("/catalog/products/999999999")
    assert response.status_code == 404


async def test_unavailable_product_hidden(client: AsyncClient) -> None:
    category = await _make_category("НетВНаличии")
    hidden = await _make_product("Скрыт", category.id, is_available=False)
    shown = await _make_product("Виден", category.id, is_available=True)

    list_response = await client.get(f"/catalog/products?category_id={category.id}")
    assert list_response.status_code == 200
    ids = [item["id"] for item in list_response.json()["items"]]
    assert hidden.id not in ids
    assert shown.id in ids

    hidden_detail = await client.get(f"/catalog/products/{hidden.id}")
    assert hidden_detail.status_code == 404

    shown_detail = await client.get(f"/catalog/products/{shown.id}")
    assert shown_detail.status_code == 200
    assert shown_detail.json()["id"] == shown.id
