"""JSON API для внешних (не браузерных) клиентов админки, Bearer-токен.

Живёт на `/api/admin/*`, а не на `/admin/*` — тот префикс с задачи «Веб-админка:
управление товарами, категориями, фото» занят HTML CRUD-страницами
(`app/web/products.py`) под cookie-токеном, которые и закрывают deliverable
брифа «владелец самостоятельно добавляет товары через админ-панель». До этой
задачи `GET /admin/products` был JSON-эндпоинтом ровно на этом пути — переехал
сюда, чтобы не конфликтовать с HTML-страницей на том же URL (см.
docs/DECISIONS.md). Целиком закрыт ролями `ADMIN_ROLES`.
"""

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import require_role
from app.core.rbac import ADMIN_ROLES
from app.db.session import get_session
from app.models.product import Product
from app.schemas.product import ProductOut
from app.services.storage import store_image

router = APIRouter(
    prefix="/api/admin",
    tags=["admin"],
    dependencies=[Depends(require_role(ADMIN_ROLES))],
)


@router.get("/products", response_model=list[ProductOut])
async def list_products(session: AsyncSession = Depends(get_session)) -> list[Product]:
    result = await session.execute(select(Product).order_by(Product.id))
    return list(result.scalars().all())


@router.post("/products/{product_id}/photo", response_model=ProductOut)
async def upload_product_photo(
    product_id: int,
    file: UploadFile = File(...),
    session: AsyncSession = Depends(get_session),
) -> Product:
    result = await session.execute(select(Product).where(Product.id == product_id))
    product = result.scalar_one_or_none()
    if product is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="товар не найден")

    product.photo_url = await store_image(file, "products", str(product_id))
    await session.commit()
    await session.refresh(product)
    return product
