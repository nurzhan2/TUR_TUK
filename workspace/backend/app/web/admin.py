"""Веб-админка: вход, сводка, заказы.

HTML под cookie на `/admin/*`; JSON для программных клиентов — `app/api/admin.py`.
Товары и категории — `app/web/products.py`, отели — `hotels.py`, промокоды —
`promo.py`, настройки сервиса — `settings.py`, сотрудники — `staff.py`.
"""

from __future__ import annotations

import re
from datetime import date as date_cls
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, Form, HTTPException, Query, Request, status
from fastapi.responses import JSONResponse
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased, selectinload

from app.core.config import get_settings
from app.core.passwords import verify_password
from app.core.rbac import ADMIN_ROLES
from app.core.security import create_access_token
from app.db.session import get_session
from app.models.order import Order, OrderPaymentStatus, OrderStatus
from app.models.order_item import OrderItem
from app.models.order_status_log import OrderStatusLog
from app.models.product import Product
from app.models.role import Role, RoleCode
from app.models.user import User
from app.web.deps import ADMIN_COOKIE_NAME, get_admin_user, no_store
from app.web.ui import NAV_ITEMS, STATUS_LABELS, redirect, render, templates  # noqa: F401

router = APIRouter(prefix="/admin", tags=["admin-web"])

ADMIN_SESSION_MINUTES = 12 * 60

# Тестовый владелец для ADMIN_TEST_LOGIN (только локально и в тестах).
TEST_ADMIN_PHONE = "+79990000001"


def normalize_phone(raw: str) -> str:
    digits = re.sub(r"\D", "", raw or "")
    if len(digits) == 11 and digits.startswith("8"):
        digits = "7" + digits[1:]
    return f"+{digits}" if digits else ""


def _set_admin_cookie(response, user_id: int) -> None:
    response.set_cookie(
        ADMIN_COOKIE_NAME,
        create_access_token(user_id, expires_minutes=ADMIN_SESSION_MINUTES),
        max_age=ADMIN_SESSION_MINUTES * 60,
        httponly=True,
        samesite="lax",
        secure=get_settings().environment == "production",
    )


def _safe_next(raw: str | None) -> str:
    return raw if raw and raw.startswith("/admin") and not raw.startswith("//") else "/admin/"


@router.get("/login")
async def login_form(request: Request, next: str | None = None):
    return no_store(templates.TemplateResponse(
        request, "admin/login.html", {"error": None, "next": _safe_next(next), "phone": ""}
    ))


@router.post("/login")
async def login_submit(
    request: Request,
    phone: str = Form(...),
    password: str = Form(...),
    next: str = Form("/admin/"),
    session: AsyncSession = Depends(get_session),
):
    normalized = normalize_phone(phone)
    user = (
        await session.execute(
            select(User).options(selectinload(User.role)).where(User.phone == normalized)
        )
    ).scalar_one_or_none()

    ok = (
        user is not None
        and user.is_active
        and user.role.code in ADMIN_ROLES
        and verify_password(password, user.password_hash)
    )
    if not ok:
        return no_store(templates.TemplateResponse(
            request,
            "admin/login.html",
            {"error": "Неверный телефон или пароль", "next": _safe_next(next), "phone": phone},
            status_code=status.HTTP_400_BAD_REQUEST,
        ))

    response = redirect(_safe_next(next))
    _set_admin_cookie(response, user.id)
    return response


@router.post("/logout")
async def logout():
    response = redirect("/admin/login")
    response.delete_cookie(ADMIN_COOKIE_NAME)
    return response


@router.post("/test-login")
async def test_login(session: AsyncSession = Depends(get_session)):
    """Вход без пароля за флагом `ADMIN_TEST_LOGIN=1` — только для тестов и
    локальной отладки. В продакшене флаг выключен и маршрут отвечает 404."""
    if not get_settings().admin_test_login:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)

    user = (
        await session.execute(
            select(User).options(selectinload(User.role)).where(User.phone == TEST_ADMIN_PHONE)
        )
    ).scalar_one_or_none()
    if user is None:
        owner_role = (
            await session.execute(select(Role).where(Role.code == RoleCode.OWNER.value))
        ).scalar_one()
        user = User(phone=TEST_ADMIN_PHONE, name="Test Admin", role_id=owner_role.id)
        session.add(user)
        await session.flush()
    await session.commit()

    response = no_store(JSONResponse({"ok": True}))
    _set_admin_cookie(response, user.id)
    return response


@router.get("/")
async def dashboard(
    request: Request,
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
):
    now = datetime.now(timezone.utc)
    day_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    week_start = day_start - timedelta(days=6)

    async def scalar(query):
        return (await session.execute(query)).scalar_one()

    paid_or_delivered = or_(
        Order.payment_status == OrderPaymentStatus.PAID, Order.status == OrderStatus.DELIVERED
    )
    stats = {
        "orders_today": await scalar(
            select(func.count(Order.id)).where(Order.created_at >= day_start)
        ),
        "revenue_today": await scalar(
            select(func.coalesce(func.sum(Order.total), 0)).where(
                Order.created_at >= day_start, paid_or_delivered
            )
        ),
        "revenue_week": await scalar(
            select(func.coalesce(func.sum(Order.total), 0)).where(
                Order.created_at >= week_start, paid_or_delivered
            )
        ),
        "active_orders": await scalar(
            select(func.count(Order.id)).where(
                Order.status.in_([
                    OrderStatus.CREATED, OrderStatus.ACCEPTED,
                    OrderStatus.ASSEMBLING, OrderStatus.DELIVERING,
                ])
            )
        ),
        "products": await scalar(select(func.count(Product.id))),
        "products_hidden": await scalar(
            select(func.count(Product.id)).where(Product.is_available.is_(False))
        ),
        "products_no_photo": await scalar(
            select(func.count(Product.id)).where(
                or_(Product.photo_url.is_(None), Product.photo_url == "")
            )
        ),
    }

    recent = (
        await session.execute(
            select(Order, User)
            .join(User, Order.user_id == User.id)
            .order_by(Order.created_at.desc())
            .limit(8)
        )
    ).all()

    return render(request, "admin/dashboard.html", admin, "/admin/", stats=stats, recent=recent)


@router.get("/orders")
async def orders_list(
    request: Request,
    status: str | None = Query(None),
    date: str | None = Query(None),
    q: str | None = Query(None),
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
):
    status_value = status if status in STATUS_LABELS else None
    parsed_date: date_cls | None = None
    if date:
        try:
            parsed_date = date_cls.fromisoformat(date)
        except ValueError:
            parsed_date = None
    search = q.strip() if q else None

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
        conditions = [User.name.ilike(pattern), User.phone.ilike(pattern), Order.hotel_name.ilike(pattern)]
        if search.lstrip("#").isdigit():
            conditions.append(Order.id == int(search.lstrip("#")))
        query = query.where(or_(*conditions))
    rows = (await session.execute(query.order_by(Order.created_at.desc()).limit(300))).all()

    return render(
        request,
        "admin/orders_list.html",
        admin,
        "/admin/orders",
        rows=rows,
        filters={"status": status_value, "date": date or "", "q": search or ""},
    )


@router.get("/orders/{order_id}")
async def order_detail(
    request: Request,
    order_id: int,
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
):
    order = (
        await session.execute(
            select(Order)
            .options(selectinload(Order.items).selectinload(OrderItem.product))
            .where(Order.id == order_id)
        )
    ).scalar_one_or_none()
    if order is None:
        raise HTTPException(status_code=404, detail="заказ не найден")

    client = await session.get(User, order.user_id)
    courier = await session.get(User, order.courier_id) if order.courier_id else None

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
            .where(Role.code == RoleCode.COURIER.value, User.is_active.is_(True))
            .order_by(User.name)
        )
    ).scalars().all()

    return render(
        request,
        "admin/order_detail.html",
        admin,
        "/admin/orders",
        order=order,
        client=client,
        courier=courier,
        statuses=list(STATUS_LABELS.items()),
        log_rows=log_rows,
        couriers=couriers,
    )


@router.post("/orders/{order_id}/status")
async def update_order_status_web(
    order_id: int,
    new_status: str = Form(..., alias="status"),
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
):
    """Ручная смена статуса администратором — без графа переходов курьерского
    API: это исправление ошибок вручную."""
    order = await session.get(Order, order_id)
    if order is None:
        raise HTTPException(status_code=404, detail="заказ не найден")
    try:
        target = OrderStatus(new_status)
    except ValueError:
        raise HTTPException(status_code=422, detail="неизвестный статус")

    if target != order.status:
        session.add(OrderStatusLog(
            order_id=order.id, from_status=order.status, to_status=target, changed_by=admin.id
        ))
        order.status = target
        await session.commit()
    return redirect(f"/admin/orders/{order_id}", "saved")


@router.post("/orders/{order_id}/assign-courier")
async def assign_courier_web(
    order_id: int,
    courier_id: int = Form(...),
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
):
    order = await session.get(Order, order_id)
    if order is None:
        raise HTTPException(status_code=404, detail="заказ не найден")
    courier = (
        await session.execute(
            select(User)
            .join(Role, User.role_id == Role.id)
            .where(User.id == courier_id, Role.code == RoleCode.COURIER.value)
        )
    ).scalar_one_or_none()
    if courier is None:
        raise HTTPException(status_code=422, detail="курьер не найден")
    order.courier_id = courier.id
    await session.commit()
    return redirect(f"/admin/orders/{order_id}", "saved")
