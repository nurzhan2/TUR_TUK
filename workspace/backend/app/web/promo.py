"""Веб-админка: промокоды — процент или фиксированная скидка, срок, лимит."""

from __future__ import annotations

from datetime import datetime, time, timezone

from fastapi import APIRouter, Depends, Form, HTTPException, Request
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_session
from app.models.order import Order
from app.models.promo_code import PromoCode
from app.models.user import User
from app.web.deps import get_admin_user
from app.web.ui import parse_float, parse_int, redirect, render

router = APIRouter(prefix="/admin", tags=["admin-web-promo"])


async def _promo_or_404(session: AsyncSession, promo_id: int) -> PromoCode:
    promo = await session.get(PromoCode, promo_id)
    if promo is None:
        raise HTTPException(status_code=404, detail="промокод не найден")
    return promo


def _fill(promo: PromoCode, *, code, title, kind, value, valid_until, max_uses, is_active) -> str | None:
    code = code.strip().upper().replace(" ", "")
    amount = parse_float(value)
    if not code:
        return "Укажите код"
    if amount is None or amount <= 0:
        return "Укажите размер скидки"
    if kind == "percent" and amount > 100:
        return "Процент не может быть больше 100"
    promo.code = code
    promo.title = title.strip() or None
    promo.discount_percent = amount if kind == "percent" else None
    promo.discount_amount = amount if kind == "fixed" else None
    promo.valid_until = None
    if valid_until.strip():
        try:
            day = datetime.fromisoformat(valid_until.strip()).date()
            promo.valid_until = datetime.combine(day, time(23, 59, 59), tzinfo=timezone.utc)
        except ValueError:
            return "Дата в формате ГГГГ-ММ-ДД"
    uses = parse_int(max_uses, 0)
    promo.max_uses = uses if uses > 0 else None
    promo.is_active = is_active is not None
    return None


@router.get("/promo")
async def promo_list(
    request: Request,
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
):
    promos = list((await session.execute(select(PromoCode).order_by(PromoCode.created_at.desc()))).scalars())
    revenue = dict(
        (await session.execute(
            select(Order.promo_id, func.count(Order.id)).where(Order.promo_id.is_not(None)).group_by(Order.promo_id)
        )).all()
    )
    return render(
        request, "admin/promo_list.html", admin, "/admin/promo",
        promos=promos, orders_by_promo=revenue, now=datetime.now(timezone.utc),
    )


@router.get("/promo/new")
async def promo_new_form(request: Request, admin: User = Depends(get_admin_user)):
    return render(
        request, "admin/promo_form.html", admin, "/admin/promo",
        promo=None, form_action="/admin/promo/new", error=None,
    )


@router.post("/promo/new")
async def promo_create(
    request: Request,
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
    code: str = Form(""),
    title: str = Form(""),
    kind: str = Form("percent"),
    value: str = Form(""),
    valid_until: str = Form(""),
    max_uses: str = Form(""),
    is_active: str | None = Form(None),
):
    promo = PromoCode()
    error = _fill(promo, code=code, title=title, kind=kind, value=value,
                  valid_until=valid_until, max_uses=max_uses, is_active=is_active)
    if error is None:
        exists = (
            await session.execute(select(PromoCode).where(func.lower(PromoCode.code) == promo.code.lower()))
        ).scalar_one_or_none()
        if exists:
            error = "Такой код уже есть"
    if error:
        return render(
            request, "admin/promo_form.html", admin, "/admin/promo",
            promo=None, form_action="/admin/promo/new", error=error,
            draft={"code": code, "title": title, "kind": kind, "value": value,
                   "valid_until": valid_until, "max_uses": max_uses},
        )
    session.add(promo)
    await session.commit()
    return redirect("/admin/promo", "created")


@router.get("/promo/{promo_id}/edit")
async def promo_edit_form(
    request: Request,
    promo_id: int,
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
):
    promo = await _promo_or_404(session, promo_id)
    return render(
        request, "admin/promo_form.html", admin, "/admin/promo",
        promo=promo, form_action=f"/admin/promo/{promo_id}/edit", error=None,
    )


@router.post("/promo/{promo_id}/edit")
async def promo_edit_submit(
    request: Request,
    promo_id: int,
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
    code: str = Form(""),
    title: str = Form(""),
    kind: str = Form("percent"),
    value: str = Form(""),
    valid_until: str = Form(""),
    max_uses: str = Form(""),
    is_active: str | None = Form(None),
):
    promo = await _promo_or_404(session, promo_id)
    error = _fill(promo, code=code, title=title, kind=kind, value=value,
                  valid_until=valid_until, max_uses=max_uses, is_active=is_active)
    if error is None:
        clash = (
            await session.execute(select(PromoCode).where(
                func.lower(PromoCode.code) == promo.code.lower(), PromoCode.id != promo_id
            ))
        ).scalar_one_or_none()
        if clash:
            error = "Такой код уже есть"
    if error:
        await session.rollback()
        promo = await _promo_or_404(session, promo_id)
        return render(
            request, "admin/promo_form.html", admin, "/admin/promo",
            promo=promo, form_action=f"/admin/promo/{promo_id}/edit", error=error,
        )
    await session.commit()
    return redirect("/admin/promo", "saved")


@router.post("/promo/{promo_id}/toggle")
async def promo_toggle(
    promo_id: int,
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
):
    promo = await _promo_or_404(session, promo_id)
    promo.is_active = not promo.is_active
    await session.commit()
    return redirect("/admin/promo", "saved")


@router.post("/promo/{promo_id}/delete")
async def promo_delete(
    promo_id: int,
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
):
    """Код, по которому уже были заказы, выключается, а не удаляется."""
    promo = await _promo_or_404(session, promo_id)
    used = (
        await session.execute(select(func.count(Order.id)).where(Order.promo_id == promo_id))
    ).scalar_one()
    if used:
        promo.is_active = False
    else:
        await session.delete(promo)
    await session.commit()
    return redirect("/admin/promo", "deleted" if not used else "saved")
