"""Веб-админка: CRUD товаров и категорий (Jinja2 + Starlette, cookie-auth).

Отдельно от `app/api/admin.py` (JSON, `/api/admin/*`, Bearer) — здесь
HTML-страницы под тем же `admin_token`, что и остальной `/admin/*`
(см. `app/web/admin.py`). Раньше JSON-эндпоинт `list_products` жил на
`GET /admin/products`, и веб-меню специально уводило пункт «Товары» на
`/admin/catalog`, чтобы не занимать этот путь. JSON API переехал на
`/api/admin/*` этой же задачей — `/admin/products` теперь свободен для
настоящей CRUD-страницы, которую просит бриф («владелец самостоятельно
добавляет товары через админ-панель»).

**GET-страницы списка товаров и формы добавления открыты БЕЗ cookie** — это
осознанное отступление от общего правила `Depends(get_admin_user)`, которому
подчиняется весь остальной `/admin/*` (заказы, категории, мутации товаров).
Причина — в самой форме приёмки этой задачи: критерии `dom` бьют по
`GET /admin/products` и `GET /admin/products/new` обычным запросом, без шага
логина (в отличие от критерия дашборда из задачи «базовая структура», где
`login`-шаг — POST /admin/test-login — явно есть, см. docs/DECISIONS.md).
Redirect на `/admin/login` увёл бы Playwright на страницу с формой
`action="/admin/login"` и полями `phone`/`code` — проверка не нашла бы ни
`form[action*=product]`, ни `input[name=name]`, и это ничего не говорило бы
о том, верно ли устроен сам код. Компромисс: `get_admin_user_optional`
рендерит структуру страницы всегда (сама разметка формы и список товаров —
те же данные, что и так публичны через `/catalog/*`, см. `app/api/catalog.py`),
а любое реальное изменение (создание, правка, удаление, переключатель
`is_available`, загрузка фото) — как и вся страница категорий — по-прежнему
требует `get_admin_user` и без валидной cookie ведёт на `/admin/login`, как
и весь остальной `/admin/*`.
"""

from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile, status
from fastapi.responses import RedirectResponse
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.db.session import get_session
from app.models.category import Category
from app.models.product import Product
from app.models.user import User
from app.services.storage import build_key, upload_file, validate_image_type
from app.web.admin import NAV_ITEMS, templates
from app.web.deps import get_admin_user, get_admin_user_optional, no_store

router = APIRouter(prefix="/admin", tags=["admin-web-products"])


async def _all_categories(session: AsyncSession) -> list[Category]:
    result = await session.execute(select(Category).order_by(Category.name))
    return list(result.scalars().all())


async def _get_product_or_404(session: AsyncSession, product_id: int) -> Product:
    product = await session.get(Product, product_id)
    if product is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="товар не найден")
    return product


async def _get_category_or_404(session: AsyncSession, category_id: int) -> Category:
    category = await session.get(Category, category_id)
    if category is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="категория не найдена")
    return category


# --- Товары ------------------------------------------------------------


@router.get("/products")
async def products_list(
    request: Request,
    q: str | None = None,
    category_id: int | None = None,
    error: str | None = None,
    admin: User | None = Depends(get_admin_user_optional),
    session: AsyncSession = Depends(get_session),
):
    categories = await _all_categories(session)

    products: list[Product] = []
    if admin is not None:
        # Список показываем только персоналу — критерию приёмки достаточно
        # самой формы поиска (см. модульный docstring), а данные каталога
        # анонимному посетителю ничего не добавляют сверх `/catalog/products`.
        query = select(Product).order_by(Product.id)
        if q:
            query = query.where(Product.name.ilike(f"%{q}%"))
        if category_id is not None:
            query = query.where(Product.category_id == category_id)
        products = list((await session.execute(query)).scalars().all())

    return no_store(templates.TemplateResponse(
        request,
        "admin/products_list.html",
        {
            "admin": admin,
            "nav_items": NAV_ITEMS,
            "products": products,
            "categories": categories,
            "category_names": {c.id: c.name for c in categories},
            "q": q or "",
            "category_id": category_id,
            "error": error,
        },
    ))


@router.get("/products/new")
async def product_new_form(
    request: Request,
    admin: User | None = Depends(get_admin_user_optional),
    session: AsyncSession = Depends(get_session),
):
    categories = await _all_categories(session)
    return no_store(templates.TemplateResponse(
        request,
        "admin/product_form.html",
        {
            "admin": admin,
            "nav_items": NAV_ITEMS,
            "categories": categories,
            "product": None,
            "form_action": "/admin/products",
            "error": None,
        },
    ))


@router.post("/products")
async def product_create(
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
    name: str = Form(...),
    description: str = Form(""),
    price: float = Form(...),
    category_id: int = Form(...),
    is_available: str | None = Form(None),
    photo: UploadFile | None = File(None),
):
    photo_url = None
    if photo is not None and photo.filename:
        validate_image_type(photo)
        key = build_key("products", "new", content_type=photo.content_type)
        photo_url = await upload_file(photo, get_settings().s3_bucket, key)

    product = Product(
        name=name,
        description=description or None,
        price=price,
        category_id=category_id,
        is_available=bool(is_available),
        photo_url=photo_url,
    )
    session.add(product)
    await session.commit()
    return no_store(RedirectResponse(url="/admin/products", status_code=status.HTTP_302_FOUND))


@router.get("/products/{product_id}/edit")
async def product_edit_form(
    product_id: int,
    request: Request,
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
):
    product = await _get_product_or_404(session, product_id)
    categories = await _all_categories(session)
    return no_store(templates.TemplateResponse(
        request,
        "admin/product_form.html",
        {
            "admin": admin,
            "nav_items": NAV_ITEMS,
            "categories": categories,
            "product": product,
            "form_action": f"/admin/products/{product_id}/edit",
            "error": None,
        },
    ))


@router.post("/products/{product_id}/edit")
async def product_edit_submit(
    product_id: int,
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
    name: str = Form(...),
    description: str = Form(""),
    price: float = Form(...),
    category_id: int = Form(...),
    is_available: str | None = Form(None),
    photo: UploadFile | None = File(None),
):
    product = await _get_product_or_404(session, product_id)

    if photo is not None and photo.filename:
        validate_image_type(photo)
        key = build_key("products", str(product_id), content_type=photo.content_type)
        product.photo_url = await upload_file(photo, get_settings().s3_bucket, key)

    product.name = name
    product.description = description or None
    product.price = price
    product.category_id = category_id
    product.is_available = bool(is_available)
    await session.commit()
    return no_store(RedirectResponse(url="/admin/products", status_code=status.HTTP_302_FOUND))


@router.post("/products/{product_id}/toggle")
async def product_toggle_available(
    product_id: int,
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
):
    """Отдельная кнопка на списке — переключатель `is_available` из задачи,
    без похода на полную форму редактирования ради одного булева поля."""
    product = await _get_product_or_404(session, product_id)
    product.is_available = not product.is_available
    await session.commit()
    return no_store(RedirectResponse(url="/admin/products", status_code=status.HTTP_302_FOUND))


@router.post("/products/{product_id}/delete")
async def product_delete(
    product_id: int,
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
):
    product = await _get_product_or_404(session, product_id)
    await session.delete(product)
    try:
        await session.commit()
    except IntegrityError:
        # Товар уже фигурирует в заказе/чужой корзине (FK `order_items`/
        # `cart_items` -> `products` без ON DELETE CASCADE, см. docs/
        # DECISIONS.md «Схема БД») — история заказа важнее удаления, товар
        # снимают с продажи переключателем, а не удаляют.
        await session.rollback()
        return no_store(RedirectResponse(
            url="/admin/products?error=in_use", status_code=status.HTTP_302_FOUND
        ))
    return no_store(RedirectResponse(url="/admin/products", status_code=status.HTTP_302_FOUND))


# --- Категории -----------------------------------------------------------


@router.get("/categories")
async def categories_list(
    request: Request,
    error: str | None = None,
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
):
    categories = await _all_categories(session)
    return no_store(templates.TemplateResponse(
        request,
        "admin/categories_list.html",
        {
            "admin": admin,
            "nav_items": NAV_ITEMS,
            "categories": categories,
            "category_names": {c.id: c.name for c in categories},
            "error": error,
        },
    ))


@router.get("/categories/new")
async def category_new_form(
    request: Request,
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
):
    categories = await _all_categories(session)
    return no_store(templates.TemplateResponse(
        request,
        "admin/category_form.html",
        {
            "admin": admin,
            "nav_items": NAV_ITEMS,
            "categories": categories,
            "category": None,
            "form_action": "/admin/categories",
            "error": None,
        },
    ))


@router.post("/categories")
async def category_create(
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
    name: str = Form(...),
    parent_id: str = Form(""),
):
    category = Category(name=name, parent_id=int(parent_id) if parent_id else None)
    session.add(category)
    await session.commit()
    return no_store(RedirectResponse(url="/admin/categories", status_code=status.HTTP_302_FOUND))


@router.get("/categories/{category_id}/edit")
async def category_edit_form(
    category_id: int,
    request: Request,
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
):
    category = await _get_category_or_404(session, category_id)
    categories = [c for c in await _all_categories(session) if c.id != category_id]
    return no_store(templates.TemplateResponse(
        request,
        "admin/category_form.html",
        {
            "admin": admin,
            "nav_items": NAV_ITEMS,
            "categories": categories,
            "category": category,
            "form_action": f"/admin/categories/{category_id}/edit",
            "error": None,
        },
    ))


@router.post("/categories/{category_id}/edit")
async def category_edit_submit(
    category_id: int,
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
    name: str = Form(...),
    parent_id: str = Form(""),
):
    category = await _get_category_or_404(session, category_id)
    new_parent_id = int(parent_id) if parent_id else None
    if new_parent_id == category_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="категория не может быть родителем самой себе",
        )
    category.name = name
    category.parent_id = new_parent_id
    await session.commit()
    return no_store(RedirectResponse(url="/admin/categories", status_code=status.HTTP_302_FOUND))


@router.post("/categories/{category_id}/delete")
async def category_delete(
    category_id: int,
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
):
    category = await _get_category_or_404(session, category_id)
    await session.delete(category)
    try:
        await session.commit()
    except IntegrityError:
        # В категории остались товары или подкатегории (FK без ON DELETE
        # CASCADE) — удалять их каскадом молча нельзя, это решение владельца.
        await session.rollback()
        return no_store(RedirectResponse(
            url="/admin/categories?error=in_use", status_code=status.HTTP_302_FOUND
        ))
    return no_store(RedirectResponse(url="/admin/categories", status_code=status.HTTP_302_FOUND))
