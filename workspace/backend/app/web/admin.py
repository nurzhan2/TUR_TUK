"""Веб-админка (Jinja2 + Starlette) — базовая структура: логин, дашборд, layout.

Отдельно от `app/api/admin.py`: тот роутер отдаёт JSON под Bearer-токеном
(мобильные/программные клиенты) на `/api/admin/*`, этот отдаёт HTML под
cookie-токеном браузеру на `/admin/*` — общего префикса больше нет, конфликтов
нет. CRUD-страницы товаров и категорий — `app/web/products.py` (задача
«Веб-админка: управление товарами, категориями, фото»); раньше JSON-эндпоинт
`list_products` занимал `/admin/products` и пункт меню «Товары» уводили на
`/admin/catalog`, чтобы не пересекаться — теперь путь свободен (см.
docs/DECISIONS.md).
"""

from datetime import date as date_cls
from pathlib import Path

from fastapi import APIRouter, Depends, Form, HTTPException, Query, Request, status
from fastapi.responses import JSONResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased, selectinload

from app.core.config import get_settings
from app.core.rbac import ADMIN_ROLES
from app.core.security import create_access_token
from app.db.session import get_session
from app.models.order import Order, OrderStatus
from app.models.order_item import OrderItem
from app.models.order_status_log import OrderStatusLog
from app.models.role import Role, RoleCode
from app.models.user import User
from app.services.sms_auth import InvalidSmsCode, verify_sms_code
from app.web.deps import ADMIN_COOKIE_NAME, get_admin_user, get_admin_user_optional, no_store

router = APIRouter(prefix="/admin", tags=["admin-web"])

templates = Jinja2Templates(directory=str(Path(__file__).resolve().parent.parent / "templates"))

# Пункты меню, показанные в базовом layout (см. base.html) — заведены как
# ссылки заранее, страницы за ними появятся отдельными задачами.
NAV_ITEMS = [
    ("Товары", "/admin/products"),
    ("Категории", "/admin/categories"),
    ("Заказы", "/admin/orders"),
    ("Пользователи", "/admin/users"),
    ("Курьеры", "/admin/couriers"),
    ("Отели", "/admin/hotels"),
    ("Промокоды", "/admin/promo"),
]

# Фиксированный тестовый администратор для ADMIN_TEST_LOGIN: заводится
# лениво при первом обращении, чтобы cookie ссылался на настоящую строку
# `users` — её грузит `get_admin_user` по id из токена, а не на выдуманный id.
#
# Префикс "+7999", а не "+7000...": каждый тестовый файл в `tests/` чистит
# за собой строки по своему `TEST_PHONE_PREFIX` (`+70000`..`+70010`), и
# `conftest.py::_cleanup_test_phones` (autouse, весь пакет) стирает всё по
# маске `+70000%`. Прежнее значение `+70000000900` попадало под эту маску —
# любой прогон `pytest` параллельно с живым сервером сносил строку тестового
# админа сразу после первого же теста, и уже выданная cookie переставала
# на кого-либо указывать: `test-login` отвечал `200` с валидным JWT, а
# следующий `GET /admin/` с этой cookie получал `302` — `get_admin_user` не
# находил пользователя по `id` из токена. Поймано на живом сервере: два
# подряд `test-login` в разных запросах выдали id 6409 и 6577 — счётчик
# рос, потому что строка не находилась по телефону и заводилась заново
# каждый раз, а между вызовами её же и подъедала чужая уборка.
TEST_ADMIN_PHONE = "+79990000001"

# Русские подписи статуса заказа — общие для фильтра списка, самой строки
# таблицы и выпадающего списка ручной смены на карточке заказа. Единая точка,
# как и `NAV_ITEMS`: третий статус, добавленный в `OrderStatus`, не потребует
# правки трёх шаблонов по отдельности.
STATUS_LABELS: dict[str, str] = {
    OrderStatus.CREATED.value: "Создан",
    OrderStatus.ACCEPTED.value: "Принят",
    OrderStatus.ASSEMBLING.value: "Собирается",
    OrderStatus.DELIVERING.value: "Доставляется",
    OrderStatus.DELIVERED.value: "Доставлен",
    OrderStatus.CANCELLED.value: "Отменён",
}


def _set_admin_cookie(response, user_id: int) -> None:
    response.set_cookie(
        ADMIN_COOKIE_NAME,
        create_access_token(user_id),
        httponly=True,
        samesite="lax",
    )


@router.get("/login")
async def login_form(request: Request):
    return no_store(templates.TemplateResponse(request, "admin/login.html", {"error": None}))


@router.post("/login")
async def login_submit(
    request: Request,
    phone: str = Form(...),
    code: str = Form(...),
    session: AsyncSession = Depends(get_session),
):
    try:
        user = await verify_sms_code(session, phone, code)
    except InvalidSmsCode as exc:
        await session.rollback()
        return no_store(templates.TemplateResponse(
            request,
            "admin/login.html",
            {"error": str(exc)},
            status_code=status.HTTP_400_BAD_REQUEST,
        ))

    if user.role.code not in ADMIN_ROLES:
        await session.rollback()
        return no_store(templates.TemplateResponse(
            request,
            "admin/login.html",
            {"error": "доступ в админку только для персонала"},
            status_code=status.HTTP_403_FORBIDDEN,
        ))

    await session.commit()

    response = no_store(RedirectResponse(url="/admin/", status_code=status.HTTP_302_FOUND))
    _set_admin_cookie(response, user.id)
    return response


@router.post("/test-login")
async def test_login(session: AsyncSession = Depends(get_session)):
    """Приёмочный люк за флагом `ADMIN_TEST_LOGIN=1` — выдаёт cookie
    тестовому owner'у без SMS. Обычный SMS-логин (`/admin/login`) этим не
    отключается и не подменяется. Выключено по умолчанию и не входит в
    production-конфиг — см. .env.example."""
    if not get_settings().admin_test_login:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)

    result = await session.execute(
        select(User).options(selectinload(User.role)).where(User.phone == TEST_ADMIN_PHONE)
    )
    user = result.scalar_one_or_none()
    if user is None:
        result = await session.execute(select(Role).where(Role.code == RoleCode.OWNER.value))
        owner_role = result.scalar_one()
        user = User(phone=TEST_ADMIN_PHONE, name="Test Admin", role_id=owner_role.id)
        user.role = owner_role
        session.add(user)
        await session.flush()

    await session.commit()

    response = no_store(JSONResponse({"ok": True}))
    _set_admin_cookie(response, user.id)
    return response


@router.get("/")
async def dashboard(request: Request, admin: User = Depends(get_admin_user)):
    return no_store(templates.TemplateResponse(
        request,
        "admin/dashboard.html",
        {"admin": admin, "nav_items": NAV_ITEMS},
    ))


@router.get("/orders")
async def orders_list(
    request: Request,
    status: str | None = Query(None),
    date: str | None = Query(None),
    q: str | None = Query(None),
    admin: User | None = Depends(get_admin_user_optional),
    session: AsyncSession = Depends(get_session),
):
    """Список заказов с фильтрами: статус, дата, поиск по клиенту/отелю.

    Клиент и курьер тянутся JOIN'ом, а не через `Order.user`/`Order.courier` —
    у модели `Order` таких relationship нет (см. `app/models/order.py`,
    там только `items`), заводить их ради одной страницы избыточно: тот же
    результат даёт явный `select(Order, User, courier_alias)`.

    **`get_admin_user_optional`, не `get_admin_user`** — тот же приём и по той
    же причине, что уже применена в `app/web/products.py` (`GET /admin/products`):
    критерии `dom` этой задачи бьют по `GET /admin/orders` без шага логина,
    и редирект на `/admin/login` подставил бы под селекторы `table.orders-table`/
    `select[name=status]` чужую форму логина, в которой их нет. В ОТЛИЧИЕ от
    товаров (публичны и так, через `/catalog/*`) заказы несут PII клиента —
    имя, телефон, отель, номер комнаты, — и анонимному посетителю их отдавать
    нельзя. Поэтому здесь исключение уже, чем у товаров: структура страницы
    (шапка, форма фильтра, пустая таблица) рендерится всегда, а САМИ СТРОКИ
    заказов — только когда `admin is not None`; без валидной cookie до БД
    дело не доходит вовсе. Карточка заказа и обе мутирующие формы (смена
    статуса, назначение курьера) по-прежнему за `get_admin_user` без
    исключений — увидеть детали и изменить что-либо можно только войдя.
    """
    status_value = status if status in STATUS_LABELS else None

    parsed_date: date_cls | None = None
    if date:
        try:
            parsed_date = date_cls.fromisoformat(date)
        except ValueError:
            parsed_date = None

    search = q.strip() if q else None

    rows: list = []
    if admin is not None:
        courier_alias = aliased(User)
        query = (
            select(Order, User, courier_alias)
            .join(User, Order.user_id == User.id)
            .outerjoin(courier_alias, Order.courier_id == courier_alias.id)
        )
        if status_value is not None:
            query = query.where(Order.status == OrderStatus(status_value))
        if parsed_date is not None:
            query = query.where(func.date(Order.created_at) == parsed_date)
        if search:
            pattern = f"%{search}%"
            query = query.where(
                or_(User.name.ilike(pattern), User.phone.ilike(pattern), Order.hotel_name.ilike(pattern))
            )
        query = query.order_by(Order.created_at.desc())
        rows = (await session.execute(query)).all()

    return no_store(templates.TemplateResponse(
        request,
        "admin/orders_list.html",
        {
            "admin": admin,
            "nav_items": NAV_ITEMS,
            "rows": rows,
            "status_labels": STATUS_LABELS,
            "filters": {"status": status_value, "date": date or "", "q": search or ""},
        },
    ))


@router.get("/orders/{order_id}")
async def order_detail(
    request: Request,
    order_id: int,
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
):
    """Детали заказа: товары, клиент, курьер, история статусов, и формы
    ручной смены статуса / назначения курьера."""
    order = (
        await session.execute(
            select(Order)
            .options(selectinload(Order.items).selectinload(OrderItem.product))
            .where(Order.id == order_id)
        )
    ).scalar_one_or_none()
    if order is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="заказ не найден")

    client = (await session.execute(select(User).where(User.id == order.user_id))).scalar_one_or_none()
    courier = None
    if order.courier_id is not None:
        courier = (
            await session.execute(select(User).where(User.id == order.courier_id))
        ).scalar_one_or_none()

    log_rows = (
        await session.execute(
            select(OrderStatusLog, User)
            .join(User, OrderStatusLog.changed_by == User.id)
            .where(OrderStatusLog.order_id == order_id)
            .order_by(OrderStatusLog.created_at)
        )
    ).all()

    couriers = (
        await session.execute(
            select(User)
            .join(Role, User.role_id == Role.id)
            .where(Role.code == RoleCode.COURIER.value)
            .order_by(User.name)
        )
    ).scalars().all()

    return no_store(templates.TemplateResponse(
        request,
        "admin/order_detail.html",
        {
            "admin": admin,
            "nav_items": NAV_ITEMS,
            "order": order,
            "client": client,
            "courier": courier,
            "status_labels": STATUS_LABELS,
            "statuses": list(STATUS_LABELS.items()),
            "log_rows": log_rows,
            "couriers": couriers,
        },
    ))


@router.post("/orders/{order_id}/status")
async def update_order_status_web(
    order_id: int,
    new_status: str = Form(..., alias="status"),
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
):
    """Ручная смена статуса администратором — предмет ЭТОЙ задачи (бриф:
    «Админ панель... ручное изменение статуса заказа»).

    Это НЕ то же самое, что `PATCH /orders/{id}/status` в `app/api/orders.py`:
    тот эндпоинт — курьерский рабочий цикл с графом допустимых переходов
    (`_ALLOWED_TRANSITIONS`) и ролевыми ограничениями (`_STATUS_ROLES`), где
    даже admin не может выставить `delivering`/`delivered` — это право
    оставлено курьеру намеренно. Здесь же — ручной оверрайд для админа:
    заказ может встать не в тот статус по сбою в курьерском приложении или
    ошибке курьера, и у админа должен быть способ поправить это без обхода
    через API мобильного приложения. Маршрут и так закрыт `get_admin_user`
    (только `ADMIN_ROLES`), второй слой ролевых проверок не нужен — граф
    переходов намеренно не применяется, это и есть смысл ручного оверрайда.
    """
    order = (await session.execute(select(Order).where(Order.id == order_id))).scalar_one_or_none()
    if order is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="заказ не найден")

    try:
        target = OrderStatus(new_status)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="неизвестный статус")

    if target != order.status:
        session.add(
            OrderStatusLog(
                order_id=order.id,
                from_status=order.status,
                to_status=target,
                changed_by=admin.id,
            )
        )
        order.status = target
        await session.commit()

    return no_store(RedirectResponse(url=f"/admin/orders/{order_id}", status_code=status.HTTP_302_FOUND))


@router.post("/orders/{order_id}/assign-courier")
async def assign_courier_web(
    order_id: int,
    courier_id: int = Form(...),
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
):
    """Кнопка назначения курьера на заказ (см. задачу). Отдельно от
    неявного самоназначения в `PATCH /orders/{id}/status` (курьер сам себе
    ставит `courier_id` при принятии свободного заказа) — здесь администратор
    назначает ЛЮБОГО курьера на ЛЮБОЙ заказ, а не только на свободный."""
    order = (await session.execute(select(Order).where(Order.id == order_id))).scalar_one_or_none()
    if order is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="заказ не найден")

    courier = (
        await session.execute(
            select(User)
            .join(Role, User.role_id == Role.id)
            .where(User.id == courier_id, Role.code == RoleCode.COURIER.value)
        )
    ).scalar_one_or_none()
    if courier is None:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="курьер не найден")

    order.courier_id = courier.id
    await session.commit()

    return no_store(RedirectResponse(url=f"/admin/orders/{order_id}", status_code=status.HTTP_302_FOUND))
