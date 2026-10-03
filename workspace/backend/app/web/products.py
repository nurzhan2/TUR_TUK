"""Веб-админка: товары и категории.

Всё, что гость видит в каталоге приложения, правится здесь: название,
описание, цена и старая цена, единица, артикул, категория, порядок, фото,
видимость. Приложение забирает это через `GET /app/config`.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile
from sqlalchemy import func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_session
from app.models.category import Category
from app.models.order_item import OrderItem
from app.models.product import Product
from app.models.user import User
from app.services.storage import store_image
from app.web.deps import get_admin_user
from app.web.ui import CATEGORY_ICONS, parse_float, parse_int, redirect, render

router = APIRouter(prefix="/admin", tags=["admin-web-products"])


async def _categories(session: AsyncSession) -> list[Category]:
    return list(
        (await session.execute(select(Category).order_by(Category.sort_order, Category.name))).scalars()
    )


async def _product_or_404(session: AsyncSession, product_id: int) -> Product:
    product = await session.get(Product, product_id)
    if product is None:
        raise HTTPException(status_code=404, detail="товар не найден")
    return product


# --- Товары -----------------------------------------------------------------


@router.get("/products")
async def products_list(
    request: Request,
    q: str | None = None,
    category: int | None = None,
    show: str = "all",
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
):
    query = select(Product)
    if q and q.strip():
        pattern = f"%{q.strip()}%"
        query = query.where(or_(Product.name.ilike(pattern), Product.sku.ilike(pattern)))
    if category:
        query = query.where(Product.category_id == category)
    if show == "hidden":
        query = query.where(Product.is_available.is_(False))
    elif show == "nophoto":
        query = query.where(or_(Product.photo_url.is_(None), Product.photo_url == ""))
    products = list(
        (await session.execute(query.order_by(Product.sort_order, Product.id))).scalars()
    )
    categories = await _categories(session)
    return render(
        request,
        "admin/products_list.html",
        admin,
        "/admin/products",
        products=products,
        categories=categories,
        category_names={c.id: c.name for c in categories},
        filters={"q": q or "", "category": category or "", "show": show},
    )


@router.get("/products/new")
async def product_new_form(
    request: Request,
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
):
    categories = await _categories(session)
    if not categories:
        return redirect("/admin/categories?need=1")
    return render(
        request, "admin/product_form.html", admin, "/admin/products",
        product=None, categories=categories, form_action="/admin/products/new", error=None,
    )


def _apply_fields(product: Product, *, name, description, price, old_price, unit, sku,
                  category_id, sort_order, is_available) -> str | None:
    price_value = parse_float(price)
    if not name.strip():
        return "Укажите название"
    if price_value is None or price_value < 0:
        return "Укажите цену числом"
    old_value = parse_float(old_price)
    product.name = name.strip()
    product.description = description.strip() or None
    product.price = price_value
    product.old_price = old_value if old_value and old_value > price_value else None
    product.unit = unit.strip() or None
    product.sku = sku.strip() or None
    product.category_id = category_id
    product.sort_order = parse_int(sort_order)
    product.is_available = is_available is not None
    return None


@router.post("/products/new")
async def product_create(
    request: Request,
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
    name: str = Form(""),
    description: str = Form(""),
    price: str = Form(""),
    old_price: str = Form(""),
    unit: str = Form(""),
    sku: str = Form(""),
    category_id: int = Form(...),
    sort_order: str = Form("0"),
    is_available: str | None = Form(None),
    photo: UploadFile | None = File(None),
):
    product = Product()
    error = _apply_fields(
        product, name=name, description=description, price=price, old_price=old_price,
        unit=unit, sku=sku, category_id=category_id, sort_order=sort_order, is_available=is_available,
    )
    if error:
        return render(
            request, "admin/product_form.html", admin, "/admin/products",
            product=None, categories=await _categories(session),
            form_action="/admin/products/new", error=error,
            draft={
                "name": name, "description": description, "price": price, "old_price": old_price,
                "unit": unit, "sku": sku, "category_id": category_id, "sort_order": sort_order,
                "is_available": is_available is not None,
            },
        )
    session.add(product)
    await session.flush()
    if photo is not None and photo.filename:
        product.photo_url = await store_image(photo, "products", str(product.id))
    await session.commit()
    return redirect("/admin/products", "created")


@router.get("/products/{product_id}/edit")
async def product_edit_form(
    request: Request,
    product_id: int,
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
):
    product = await _product_or_404(session, product_id)
    return render(
        request, "admin/product_form.html", admin, "/admin/products",
        product=product, categories=await _categories(session),
        form_action=f"/admin/products/{product_id}/edit", error=None,
    )


@router.post("/products/{product_id}/edit")
async def product_edit_submit(
    request: Request,
    product_id: int,
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
    name: str = Form(""),
    description: str = Form(""),
    price: str = Form(""),
    old_price: str = Form(""),
    unit: str = Form(""),
    sku: str = Form(""),
    category_id: int = Form(...),
    sort_order: str = Form("0"),
    is_available: str | None = Form(None),
    remove_photo: str | None = Form(None),
    photo: UploadFile | None = File(None),
):
    product = await _product_or_404(session, product_id)
    error = _apply_fields(
        product, name=name, description=description, price=price, old_price=old_price,
        unit=unit, sku=sku, category_id=category_id, sort_order=sort_order, is_available=is_available,
    )
    if error:
        await session.rollback()
        product = await _product_or_404(session, product_id)
        return render(
            request, "admin/product_form.html", admin, "/admin/products",
            product=product, categories=await _categories(session),
            form_action=f"/admin/products/{product_id}/edit", error=error,
        )
    if remove_photo:
        product.photo_url = None
    if photo is not None and photo.filename:
        product.photo_url = await store_image(photo, "products", str(product.id))
    await session.commit()
    return redirect("/admin/products", "saved")


@router.post("/products/{product_id}/toggle")
async def product_toggle_available(
    product_id: int,
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
):
    product = await _product_or_404(session, product_id)
    product.is_available = not product.is_available
    await session.commit()
    return redirect("/admin/products", "saved")


@router.post("/products/{product_id}/delete")
async def product_delete(
    product_id: int,
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
):
    """Товар из прошлых заказов не удаляется, а скрывается — иначе история
    заказов потеряла бы позиции."""
    product = await _product_or_404(session, product_id)
    used = (
        await session.execute(select(func.count(OrderItem.id)).where(OrderItem.product_id == product_id))
    ).scalar_one()
    if used:
        product.is_available = False
        await session.commit()
        return redirect("/admin/products", "saved")
    await session.delete(product)
    try:
        await session.commit()
    except IntegrityError:
        await session.rollback()
        product = await _product_or_404(session, product_id)
        product.is_available = False
        await session.commit()
    return redirect("/admin/products", "deleted")


# --- Категории --------------------------------------------------------------


@router.get("/categories")
async def categories_list(
    request: Request,
    need: int | None = None,
    error: str | None = None,
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
):
    categories = await _categories(session)
    counts = dict(
        (await session.execute(
            select(Product.category_id, func.count(Product.id)).group_by(Product.category_id)
        )).all()
    )
    message = None
    if need:
        message = "Сначала создайте хотя бы одну категорию"
    elif error == "notempty":
        message = "В категории есть товары — перенесите их, потом удаляйте"
    return render(
        request, "admin/categories.html", admin, "/admin/categories",
        categories=categories, counts=counts, icons=CATEGORY_ICONS, message=message,
    )


@router.post("/categories")
async def category_create(
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
    name: str = Form(...),
    icon: str = Form("basket"),
    sort_order: str = Form("0"),
):
    if name.strip():
        session.add(Category(name=name.strip(), icon=icon, sort_order=parse_int(sort_order)))
        await session.commit()
    return redirect("/admin/categories", "created")


@router.post("/categories/{category_id}/edit")
async def category_edit(
    category_id: int,
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
    name: str = Form(...),
    icon: str = Form("basket"),
    sort_order: str = Form("0"),
):
    category = await session.get(Category, category_id)
    if category is None:
        raise HTTPException(status_code=404, detail="категория не найдена")
    if name.strip():
        category.name = name.strip()
    category.icon = icon
    category.sort_order = parse_int(sort_order)
    await session.commit()
    return redirect("/admin/categories", "saved")


@router.post("/categories/{category_id}/delete")
async def category_delete(
    category_id: int,
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
):
    category = await session.get(Category, category_id)
    if category is None:
        raise HTTPException(status_code=404, detail="категория не найдена")
    used = (
        await session.execute(select(func.count(Product.id)).where(Product.category_id == category_id))
    ).scalar_one()
    if used:
        return redirect("/admin/categories?error=notempty")
    await session.delete(category)
    await session.commit()
    return redirect("/admin/categories", "deleted")
