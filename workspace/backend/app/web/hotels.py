"""Веб-админка: отели зоны доставки.

Список, добавление, правка, включение/выключение, импорт CSV. Выключенный
отель пропадает из списка в приложении, но остаётся в базе — старые заказы
ссылаются на него по названию. Названия уникальны без учёта регистра.
"""

from __future__ import annotations

import csv
import io
from decimal import Decimal, InvalidOperation

from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile
from sqlalchemy import func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_session
from app.models.hotel import Hotel
from app.models.user import User
from app.web.deps import get_admin_user
from app.web.ui import redirect, render

router = APIRouter(prefix="/admin", tags=["admin-web-hotels"])

CSV_COLUMNS = ("name", "address", "category", "district", "rating", "lat", "lon")


def _decimal(raw: str | None) -> Decimal | None:
    raw = (raw or "").strip().replace(",", ".")
    if not raw:
        return None
    try:
        return Decimal(raw)
    except InvalidOperation:
        return None


async def _hotel_or_404(session: AsyncSession, hotel_id: int) -> Hotel:
    hotel = await session.get(Hotel, hotel_id)
    if hotel is None:
        raise HTTPException(status_code=404, detail="отель не найден")
    return hotel


async def _find_by_name(session: AsyncSession, name: str) -> Hotel | None:
    return (
        await session.execute(select(Hotel).where(func.lower(Hotel.name) == name.strip().lower()))
    ).scalar_one_or_none()


def _fill(hotel: Hotel, *, name, address, district, lat, lon, is_active) -> None:
    hotel.name = name.strip()
    hotel.address = address.strip() or None
    hotel.district = district.strip() or None
    hotel.lat = _decimal(lat)
    hotel.lon = _decimal(lon)
    hotel.is_active = is_active is not None


@router.get("/hotels")
async def hotels_list(
    request: Request,
    q: str | None = None,
    show: str = "all",
    error: str | None = None,
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
):
    query = select(Hotel)
    if q and q.strip():
        pattern = f"%{q.strip()}%"
        query = query.where(or_(Hotel.name.ilike(pattern), Hotel.address.ilike(pattern)))
    if show == "active":
        query = query.where(Hotel.is_active.is_(True))
    elif show == "inactive":
        query = query.where(Hotel.is_active.is_(False))
    elif show == "nocoords":
        query = query.where(or_(Hotel.lat.is_(None), Hotel.lon.is_(None)))
    hotels = list((await session.execute(query.order_by(Hotel.name))).scalars())
    active_count = (
        await session.execute(select(func.count(Hotel.id)).where(Hotel.is_active.is_(True)))
    ).scalar_one()
    return render(
        request, "admin/hotels_list.html", admin, "/admin/hotels",
        hotels=hotels, active_count=active_count,
        filters={"q": q or "", "show": show},
        error="Отель с таким названием уже есть" if error == "duplicate" else None,
    )


@router.get("/hotels/new")
async def hotel_new_form(request: Request, admin: User = Depends(get_admin_user)):
    return render(
        request, "admin/hotel_form.html", admin, "/admin/hotels",
        hotel=None, form_action="/admin/hotels/new", error=None,
    )


@router.post("/hotels/new")
async def hotel_create(
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
    name: str = Form(...),
    address: str = Form(""),
    district: str = Form(""),
    lat: str = Form(""),
    lon: str = Form(""),
    is_active: str | None = Form("on"),
):
    if not name.strip() or await _find_by_name(session, name):
        return redirect("/admin/hotels?error=duplicate")
    hotel = Hotel()
    _fill(hotel, name=name, address=address, district=district, lat=lat, lon=lon, is_active=is_active)
    session.add(hotel)
    try:
        await session.commit()
    except IntegrityError:
        await session.rollback()
        return redirect("/admin/hotels?error=duplicate")
    return redirect("/admin/hotels", "created")


@router.get("/hotels/{hotel_id}/edit")
async def hotel_edit_form(
    request: Request,
    hotel_id: int,
    error: str | None = None,
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
):
    hotel = await _hotel_or_404(session, hotel_id)
    return render(
        request, "admin/hotel_form.html", admin, "/admin/hotels",
        hotel=hotel, form_action=f"/admin/hotels/{hotel_id}/edit",
        error="Отель с таким названием уже есть" if error == "duplicate" else None,
    )


@router.post("/hotels/{hotel_id}/edit")
async def hotel_edit_submit(
    hotel_id: int,
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
    name: str = Form(...),
    address: str = Form(""),
    district: str = Form(""),
    lat: str = Form(""),
    lon: str = Form(""),
    is_active: str | None = Form(None),
):
    hotel = await _hotel_or_404(session, hotel_id)
    existing = await _find_by_name(session, name)
    if existing is not None and existing.id != hotel_id:
        return redirect(f"/admin/hotels/{hotel_id}/edit?error=duplicate")
    _fill(hotel, name=name, address=address, district=district, lat=lat, lon=lon, is_active=is_active)
    try:
        await session.commit()
    except IntegrityError:
        await session.rollback()
        return redirect(f"/admin/hotels/{hotel_id}/edit?error=duplicate")
    return redirect("/admin/hotels", "saved")


@router.post("/hotels/{hotel_id}/toggle")
async def hotel_toggle(
    hotel_id: int,
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
):
    hotel = await _hotel_or_404(session, hotel_id)
    hotel.is_active = not hotel.is_active
    await session.commit()
    return redirect("/admin/hotels", "saved")


@router.post("/hotels/{hotel_id}/delete")
async def hotel_delete(
    hotel_id: int,
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
):
    hotel = await _hotel_or_404(session, hotel_id)
    await session.delete(hotel)
    await session.commit()
    return redirect("/admin/hotels", "deleted")


@router.get("/hotels/import")
async def hotels_import_form(request: Request, admin: User = Depends(get_admin_user)):
    return render(
        request, "admin/hotels_import.html", admin, "/admin/hotels", columns=CSV_COLUMNS, error=None
    )


@router.post("/hotels/import")
async def hotels_import_submit(
    request: Request,
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
    file: UploadFile = File(...),
):
    """Построчный upsert по названию. Пустая ячейка не затирает уже
    сохранённое значение — CSV можно присылать частями."""
    raw = await file.read()
    try:
        text = raw.decode("utf-8-sig")
    except UnicodeDecodeError:
        return render(
            request, "admin/hotels_import.html", admin, "/admin/hotels",
            columns=CSV_COLUMNS, error="Файл не в кодировке UTF-8",
        )

    sample = text[:2048]
    delimiter = ";" if sample.count(";") > sample.count(",") else ","
    reader = csv.DictReader(io.StringIO(text), delimiter=delimiter)
    if reader.fieldnames is None or "name" not in [f.strip().lower() for f in reader.fieldnames]:
        return render(
            request, "admin/hotels_import.html", admin, "/admin/hotels",
            columns=CSV_COLUMNS, error="В CSV нет обязательной колонки name",
        )

    for row in reader:
        values = {(k or "").strip().lower(): (v or "").strip() for k, v in row.items()}
        name = values.get("name", "")
        if not name:
            continue
        hotel = await _find_by_name(session, name)
        if hotel is None:
            hotel = Hotel(name=name)
            session.add(hotel)
        for field in ("address", "category", "district"):
            if values.get(field):
                setattr(hotel, field, values[field])
        for field in ("rating", "lat", "lon"):
            parsed = _decimal(values.get(field))
            if parsed is not None:
                setattr(hotel, field, parsed)
        await session.flush()

    await session.commit()
    return redirect("/admin/hotels", "imported")
