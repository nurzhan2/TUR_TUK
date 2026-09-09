"""Каталог: дерево категорий, пагинированный список товаров, карточка товара.

Публичный — браузинг каталога не требует авторизации ни в одном из
референсов брифа (Wildberries-style карточки). Правило «скрывать товар при
отсутствии в наличии» (deliverable) применено в одном месте — `_AVAILABLE` —
а не продублировано по каждому запросу отдельно.
"""

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_session
from app.models.category import Category
from app.models.product import Product
from app.schemas.catalog import CategoryOut, ProductPage
from app.schemas.product import ProductOut

router = APIRouter(prefix="/catalog", tags=["catalog"])

_AVAILABLE = Product.is_available.is_(True)


def _build_tree(categories: list[Category]) -> list[CategoryOut]:
    by_parent: dict[int | None, list[Category]] = {}
    for category in categories:
        by_parent.setdefault(category.parent_id, []).append(category)

    def _node(category: Category) -> CategoryOut:
        return CategoryOut(
            id=category.id,
            name=category.name,
            children=[_node(child) for child in by_parent.get(category.id, [])],
        )

    return [_node(category) for category in by_parent.get(None, [])]


@router.get("/categories", response_model=list[CategoryOut])
async def list_categories(session: AsyncSession = Depends(get_session)) -> list[CategoryOut]:
    result = await session.execute(select(Category).order_by(Category.id))
    return _build_tree(list(result.scalars().all()))


@router.get("/products", response_model=ProductPage)
async def list_products(
    category_id: int | None = None,
    search: str | None = Query(None, min_length=1),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    session: AsyncSession = Depends(get_session),
) -> ProductPage:
    query = select(Product).where(_AVAILABLE)
    if category_id is not None:
        query = query.where(Product.category_id == category_id)
    if search is not None:
        pattern = f"%{search}%"
        query = query.where(
            or_(Product.name.ilike(pattern), Product.description.ilike(pattern))
        )

    total = (
        await session.execute(select(func.count()).select_from(query.subquery()))
    ).scalar_one()

    query = query.order_by(Product.id).offset((page - 1) * limit).limit(limit)
    items = list((await session.execute(query)).scalars().all())

    return ProductPage(items=items, page=page, limit=limit, total=total)


@router.get("/products/{product_id}", response_model=ProductOut)
async def get_product(
    product_id: int, session: AsyncSession = Depends(get_session)
) -> Product:
    result = await session.execute(
        select(Product).where(Product.id == product_id, _AVAILABLE)
    )
    product = result.scalar_one_or_none()
    if product is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="товар не найден"
        )
    return product
