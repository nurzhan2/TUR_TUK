"""`GET /app/config` — всё, что приложение показывает гостю, одним ответом.

Бренд и логотип, суммы доставки, способы оплаты, склад, контакты, баннеры,
отели, категории и товары. Источник — админка (`/admin/*`), поэтому смена
цены, фото или списка отелей видна в приложении при следующем запуске без
выпуска новой версии в сторе.

Ключи в camelCase — тот же формат, что у `content/*.json`, которые
приложение держит в ассетах как запасной вариант без сети.

Промокодов здесь нет намеренно: список кодов не публикуется, проверка —
через `POST /promo/validate`.
"""

from __future__ import annotations

import hashlib
import json

from fastapi import APIRouter, Depends, Request, Response
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_session
from app.models.category import Category
from app.models.hotel import Hotel
from app.models.product import Product
from app.services.app_settings import load_settings
from app.services.storage import absolute_url

router = APIRouter(prefix="/app", tags=["app"])


def _num(value) -> float | None:
    return float(value) if value is not None else None


async def build_app_config(session: AsyncSession, base_url: str) -> dict:
    settings = await load_settings(session)
    settings["brand"]["logoUrl"] = absolute_url(settings["brand"].get("logoUrl"), base_url)

    categories = (
        await session.execute(select(Category).order_by(Category.sort_order, Category.id))
    ).scalars().all()
    products = (
        await session.execute(
            select(Product)
            .where(Product.is_available.is_(True))
            .order_by(Product.sort_order, Product.id)
        )
    ).scalars().all()
    hotels = (
        await session.execute(
            select(Hotel).where(Hotel.is_active.is_(True)).order_by(Hotel.name)
        )
    ).scalars().all()

    used_categories = {p.category_id for p in products}

    return {
        **settings,
        "hotels": [
            {
                "id": h.id,
                "name": h.name,
                "address": h.address or "",
                "lat": _num(h.lat) or 0.0,
                "lng": _num(h.lon) or 0.0,
                "active": True,
            }
            for h in hotels
        ],
        "categories": [
            {"id": c.id, "name": c.name, "icon": c.icon or "basket"}
            for c in categories
            if c.id in used_categories
        ],
        "products": [
            {
                "id": p.id,
                "sku": p.sku or f"p{p.id}",
                "categoryId": p.category_id,
                "name": p.name,
                "description": p.description or "",
                "price": float(p.price),
                "oldPrice": _num(p.old_price),
                "unit": p.unit or "шт",
                "isAvailable": True,
                "photoUrl": absolute_url(p.photo_url, base_url),
            }
            for p in products
        ],
    }


@router.get("/config")
async def app_config(
    request: Request,
    response: Response,
    session: AsyncSession = Depends(get_session),
) -> dict:
    payload = await build_app_config(session, str(request.base_url))
    body = json.dumps(payload, ensure_ascii=False, sort_keys=True).encode()
    etag = '"' + hashlib.sha1(body).hexdigest()[:16] + '"'
    payload["version"] = etag.strip('"')
    if request.headers.get("if-none-match") == etag:
        return Response(status_code=304, headers={"ETag": etag})
    response.headers["ETag"] = etag
    response.headers["Cache-Control"] = "no-cache"
    return payload
