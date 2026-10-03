"""Общее для страниц админки: шаблоны, меню, подписи, хелпер рендера."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from fastapi import Request
from fastapi.responses import RedirectResponse
from fastapi.templating import Jinja2Templates

from app.models.order import OrderStatus
from app.web.deps import no_store

templates = Jinja2Templates(directory=str(Path(__file__).resolve().parent.parent / "templates"))

# (подпись, путь, ключ иконки) — иконки рисует base.html.
NAV_ITEMS: list[tuple[str, str, str]] = [
    ("Сводка", "/admin/", "home"),
    ("Заказы", "/admin/orders", "orders"),
    ("Товары", "/admin/products", "box"),
    ("Категории", "/admin/categories", "grid"),
    ("Отели", "/admin/hotels", "hotel"),
    ("Промокоды", "/admin/promo", "tag"),
    ("Настройки", "/admin/settings", "gear"),
    ("Сотрудники", "/admin/staff", "users"),
]

STATUS_LABELS: dict[str, str] = {
    OrderStatus.CREATED.value: "Новый",
    OrderStatus.ACCEPTED.value: "Принят",
    OrderStatus.ASSEMBLING.value: "Собирается",
    OrderStatus.DELIVERING.value: "В пути",
    OrderStatus.DELIVERED.value: "Доставлен",
    OrderStatus.CANCELLED.value: "Отменён",
}

# Иконки категорий: ключ хранится в БД, приложение рисует иконку Material.
CATEGORY_ICONS: list[tuple[str, str]] = [
    ("gift", "🎁 Сувениры"),
    ("spa", "🌿 Косметика / уход"),
    ("basket", "🧺 Продукты"),
    ("cafe", "☕ Кофе и чай"),
    ("cake", "🍰 Сладости"),
    ("beach", "🏖 Пляж"),
    ("drink", "🥤 Напитки"),
    ("health", "💊 Аптечка"),
    ("baby", "🍼 Детское"),
    ("home", "🏠 Для номера"),
]

FLASH_MESSAGES: dict[str, str] = {
    "saved": "Сохранено",
    "created": "Создано",
    "deleted": "Удалено",
    "imported": "Импорт завершён",
}


def _money(value: Any) -> str:
    try:
        number = float(value)
    except (TypeError, ValueError):
        return "—"
    text = f"{number:,.2f}".replace(",", " ").replace(".00", "")
    return f"{text} ₽"


templates.env.filters["money"] = _money


def render(request: Request, template: str, admin, active: str = "", **context: Any):
    flash = FLASH_MESSAGES.get(request.query_params.get("ok", ""))
    return no_store(templates.TemplateResponse(
        request,
        template,
        {
            "admin": admin,
            "nav_items": NAV_ITEMS,
            "active": active,
            "flash": flash,
            "status_labels": STATUS_LABELS,
            **context,
        },
    ))


def redirect(url: str, ok: str | None = None) -> RedirectResponse:
    if ok:
        url += ("&" if "?" in url else "?") + f"ok={ok}"
    return no_store(RedirectResponse(url=url, status_code=302))


def parse_float(raw: str | None) -> float | None:
    if raw is None:
        return None
    raw = raw.strip().replace(" ", "").replace(",", ".")
    if not raw:
        return None
    try:
        return float(raw)
    except ValueError:
        return None


def parse_int(raw: str | None, default: int = 0) -> int:
    value = parse_float(raw)
    return int(value) if value is not None else default
