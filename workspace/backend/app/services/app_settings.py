"""Настройки сервиса из админки: чтение со слиянием с дефолтами и запись.

Документ хранится одной JSON-строкой (`app_settings.id = 1`). Всё, что
владелец не заполнил, берётся из `DEFAULTS` — поэтому новое поле настроек
добавляется здесь одной строкой, без миграции.
"""

from __future__ import annotations

import copy
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.app_setting import AppSetting

SETTINGS_ROW_ID = 1

DEFAULTS: dict[str, Any] = {
    "brand": {
        "name": "TUR TUK",
        "tagline": "Доставка в отели Кемера",
        "deliveryPromise": "Доставка в отель за 60 минут",
        "accentColor": "#8B0000",
        "logoUrl": "",
    },
    "delivery": {
        "minOrderTotal": 3000,
        "deliveryFee": 300,
        "freeDeliveryFrom": 5000,
        "etaMinutes": 60,
        "currency": "RUB",
        "currencySymbol": "₽",
    },
    "payment": {"cardEnabled": True, "sbpEnabled": True, "cashEnabled": False},
    "warehouse": {
        "name": "Склад TUR TUK, Кемер",
        "address": "Кемер, Анталья, Турция",
        "lat": 36.6021,
        "lng": 30.5619,
    },
    "contacts": {
        "phone": "",
        "whatsapp": "",
        "telegram": "",
        "email": "",
        "supportHours": "09:00 – 22:00",
        "privacyPolicyUrl": "",
        "supportUrl": "",
    },
    "languages": ["ru", "en", "tr"],
    "banners": [
        {"title": "Скидка 10% по промокоду KEMER10", "subtitle": "на первый заказ в приложении"},
        {"title": "Бесплатная доставка от 5000 ₽", "subtitle": "до рецепции вашего отеля"},
        {"title": "Турецкие сладости", "subtitle": "лукум и пахлава — привезём за час"},
    ],
}


def _merge(base: dict[str, Any], override: dict[str, Any]) -> dict[str, Any]:
    result = copy.deepcopy(base)
    for key, value in (override or {}).items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = _merge(result[key], value)
        else:
            result[key] = copy.deepcopy(value)
    return result


async def _row(session: AsyncSession) -> AppSetting:
    row = (
        await session.execute(select(AppSetting).where(AppSetting.id == SETTINGS_ROW_ID))
    ).scalar_one_or_none()
    if row is None:
        row = AppSetting(id=SETTINGS_ROW_ID, data={})
        session.add(row)
        await session.flush()
    return row


async def load_settings(session: AsyncSession) -> dict[str, Any]:
    """Полный документ настроек: сохранённое поверх дефолтов."""
    row = await _row(session)
    return _merge(DEFAULTS, row.data or {})


async def save_settings(session: AsyncSession, patch: dict[str, Any]) -> dict[str, Any]:
    """Сливает `patch` в сохранённый документ. Списки (баннеры) заменяются
    целиком, словари — по ключам. Коммит — на вызывающем."""
    row = await _row(session)
    row.data = _merge(row.data or {}, patch)
    await session.flush()
    return _merge(DEFAULTS, row.data)


def delivery_fee_for(settings: dict[str, Any], subtotal: float) -> float:
    delivery = settings["delivery"]
    free_from = float(delivery.get("freeDeliveryFrom") or 0)
    if free_from and subtotal >= free_from:
        return 0.0
    return float(delivery.get("deliveryFee") or 0)


def min_order_total(settings: dict[str, Any]) -> float:
    return float(settings["delivery"].get("minOrderTotal") or 0)
