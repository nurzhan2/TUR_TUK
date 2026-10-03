"""Веб-админка: настройки сервиса.

Бренд и логотип, суммы доставки, способы оплаты, склад, контакты, баннеры
на главной. Хранится в `app_settings` (см. `app/services/app_settings.py`),
приложение получает через `GET /app/config`, сервер считает заказ по тем же
суммам — расхождения между экраном и списанием нет.
"""

from __future__ import annotations

import re

from fastapi import APIRouter, Depends, File, Request, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_session
from app.models.user import User
from app.services.app_settings import load_settings, save_settings
from app.services.storage import absolute_url, store_image
from app.web.deps import get_admin_user
from app.web.ui import parse_float, parse_int, redirect, render

router = APIRouter(prefix="/admin", tags=["admin-web-settings"])

MAX_BANNERS = 6
_COLOR = re.compile(r"^#[0-9a-fA-F]{6}$")


@router.get("/settings")
async def settings_form(
    request: Request,
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
):
    data = await load_settings(session)
    banners = list(data.get("banners") or [])
    banners += [{"title": "", "subtitle": ""}] * max(0, MAX_BANNERS - len(banners))
    return render(
        request, "admin/settings.html", admin, "/admin/settings",
        s=data, banners=banners[:MAX_BANNERS],
        logo_preview=absolute_url(data["brand"].get("logoUrl"), str(request.base_url)),
        error=None,
    )


@router.post("/settings")
async def settings_submit(
    request: Request,
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
    logo: UploadFile | None = File(None),
):
    form = await request.form()

    def text(key: str) -> str:
        value = form.get(key)
        return value.strip() if isinstance(value, str) else ""

    def number(key: str, default: float) -> float:
        value = parse_float(text(key))
        return value if value is not None and value >= 0 else default

    current = await load_settings(session)
    color = text("accentColor")
    brand = {
        "name": text("brandName") or current["brand"]["name"],
        "tagline": text("tagline"),
        "deliveryPromise": text("deliveryPromise"),
        "accentColor": color if _COLOR.match(color) else current["brand"]["accentColor"],
    }
    if form.get("removeLogo"):
        brand["logoUrl"] = ""
    if logo is not None and logo.filename:
        brand["logoUrl"] = await store_image(logo, "brand", keep_alpha=True)

    delivery = current["delivery"]
    banners = []
    for i in range(MAX_BANNERS):
        title = text(f"banner_title_{i}")
        if title:
            banners.append({"title": title, "subtitle": text(f"banner_subtitle_{i}")})

    await save_settings(session, {
        "brand": brand,
        "delivery": {
            "minOrderTotal": number("minOrderTotal", delivery["minOrderTotal"]),
            "deliveryFee": number("deliveryFee", delivery["deliveryFee"]),
            "freeDeliveryFrom": number("freeDeliveryFrom", delivery["freeDeliveryFrom"]),
            "etaMinutes": parse_int(text("etaMinutes"), delivery["etaMinutes"]) or delivery["etaMinutes"],
        },
        "payment": {
            "cardEnabled": bool(form.get("cardEnabled")),
            "sbpEnabled": bool(form.get("sbpEnabled")),
            "cashEnabled": False,
        },
        "warehouse": {
            "name": text("warehouseName"),
            "address": text("warehouseAddress"),
            "lat": number("warehouseLat", current["warehouse"]["lat"]),
            "lng": number("warehouseLng", current["warehouse"]["lng"]),
        },
        "contacts": {
            key: text(key)
            for key in ("phone", "whatsapp", "telegram", "email", "supportHours",
                        "privacyPolicyUrl", "supportUrl")
        },
        "banners": banners,
    })
    await session.commit()
    return redirect("/admin/settings", "saved")
