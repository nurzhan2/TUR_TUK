"""Служебные команды бэкенда.

    python -m app.cli create-owner --phone +79001234567 --password '…' [--name Анастасия]
    python -m app.cli seed-content [--content ../content] [--photos ../client_app/assets/content/photos]

`create-owner` — первый вход в админку: владелец с паролем. Повторный запуск
с тем же телефоном меняет пароль.

`seed-content` — переносит каталог, настройки и промокоды из `content/*.json`
(то, на чём работало демо) в базу. Повторный запуск обновляет записи по
артикулу/названию/коду и не плодит дубли. Отели из JSON добавляются, только
если справочник отелей пуст: в базе уже есть список Кемера из миграций.
"""

from __future__ import annotations

import argparse
import asyncio
import json
from pathlib import Path

from sqlalchemy import func, select

from app.core.passwords import MIN_PASSWORD_LENGTH, hash_password
from app.db.session import async_session_factory
from app.models.category import Category
from app.models.hotel import Hotel
from app.models.product import Product
from app.models.promo_code import PromoCode
from app.models.role import Role, RoleCode
from app.models.user import User
from app.services.app_settings import save_settings
from app.services.storage import THUMB_SUFFIX, make_thumb, process_image, store_webp
from app.web.admin import normalize_phone

BACKEND_DIR = Path(__file__).resolve().parent.parent
WORKSPACE = BACKEND_DIR.parent


async def create_owner(phone: str, password: str, name: str | None) -> None:
    if len(password) < MIN_PASSWORD_LENGTH:
        raise SystemExit(f"пароль короче {MIN_PASSWORD_LENGTH} символов")
    normalized = normalize_phone(phone)
    async with async_session_factory() as session:
        role = (await session.execute(select(Role).where(Role.code == RoleCode.OWNER.value))).scalar_one()
        user = (await session.execute(select(User).where(User.phone == normalized))).scalar_one_or_none()
        if user is None:
            user = User(phone=normalized)
            session.add(user)
        user.role_id = role.id
        user.is_active = True
        user.password_hash = hash_password(password)
        if name:
            user.name = name
        await session.commit()
    print(f"владелец {normalized}: готово, вход — /admin/login")


async def _store_photo(path: Path, *parts: str) -> str | None:
    if not path.is_file():
        return None
    body, _ = process_image(path.read_bytes())
    key = "/".join([*parts, f"{path.stem}.webp"])
    return await store_webp(body, key)


def make_thumbs(media_dir: Path) -> None:
    """Превью для уже лежащих в локальном хранилище фото (загруженных до
    появления превью). Повторный запуск пропускает готовые."""
    made = 0
    for original in media_dir.rglob("*.webp"):
        if original.name.endswith(THUMB_SUFFIX):
            continue
        thumb = original.with_name(original.name[: -len(".webp")] + THUMB_SUFFIX)
        if thumb.exists():
            continue
        thumb.write_bytes(make_thumb(original.read_bytes()))
        made += 1
    print(f"превью создано: {made}")


async def seed_content(content_dir: Path, photos_dir: Path) -> None:
    catalog = json.loads((content_dir / "catalog.json").read_text(encoding="utf-8"))
    settings = json.loads((content_dir / "settings.json").read_text(encoding="utf-8"))
    hotels = json.loads((content_dir / "hotels.json").read_text(encoding="utf-8"))

    async with async_session_factory() as session:
        # Настройки: всё, кроме промокодов (они — отдельная таблица).
        patch = {k: v for k, v in settings.items() if not k.startswith("_") and k != "promoCodes"}
        brand = {k: v for k, v in patch.get("brand", {}).items() if not k.startswith("_")}
        brand.pop("logoFile", None)
        patch["brand"] = brand
        for section in ("delivery", "payment", "warehouse", "contacts"):
            if section in patch:
                patch[section] = {k: v for k, v in patch[section].items() if not k.startswith("_")}
        await save_settings(session, patch)

        # Категории — по названию.
        category_ids: dict[int, int] = {}
        for index, raw in enumerate(catalog.get("categories", [])):
            category = (
                await session.execute(select(Category).where(Category.name == raw["name"]))
            ).scalar_one_or_none()
            if category is None:
                category = Category(name=raw["name"])
                session.add(category)
            category.icon = raw.get("icon") or "basket"
            category.sort_order = (index + 1) * 10
            await session.flush()
            category_ids[raw["id"]] = category.id

        # Товары — по артикулу.
        photos = 0
        for index, raw in enumerate(catalog.get("products", [])):
            sku = raw.get("sku") or f"p{raw['id']}"
            product = (await session.execute(select(Product).where(Product.sku == sku))).scalar_one_or_none()
            if product is None:
                product = Product(sku=sku)
                session.add(product)
            product.name = raw["name"]
            product.description = raw.get("description") or None
            product.price = raw["price"]
            old = raw.get("oldPrice")
            product.old_price = old if old and old > raw["price"] else None
            product.unit = raw.get("unit") or None
            product.category_id = category_ids[raw["categoryId"]]
            product.is_available = raw.get("isAvailable", True)
            product.sort_order = (index + 1) * 10
            await session.flush()
            if not product.photo_url:
                url = await _store_photo(photos_dir / (raw.get("photo") or f"{sku}.jpg"), "products", str(product.id))
                if url:
                    product.photo_url = url
                    photos += 1

        # Промокоды — по коду.
        for raw in settings.get("promoCodes", []):
            code = raw["code"].upper()
            promo = (
                await session.execute(select(PromoCode).where(func.lower(PromoCode.code) == code.lower()))
            ).scalar_one_or_none()
            if promo is None:
                promo = PromoCode(code=code)
                session.add(promo)
            promo.title = raw.get("title") or None
            promo.discount_percent = raw["value"] if raw.get("type") == "percent" else None
            promo.discount_amount = raw["value"] if raw.get("type") == "fixed" else None
            promo.is_active = raw.get("active", True)

        hotels_total = (await session.execute(select(func.count(Hotel.id)))).scalar_one()
        added_hotels = 0
        if hotels_total == 0:
            for raw in hotels.get("hotels", []):
                session.add(Hotel(
                    name=raw["name"], address=raw.get("address") or None,
                    lat=raw.get("lat"), lon=raw.get("lng"), is_active=raw.get("active", True),
                ))
                added_hotels += 1

        await session.commit()

    print(
        f"категорий: {len(category_ids)}, товаров: {len(catalog.get('products', []))} "
        f"(фото загружено: {photos}), промокодов: {len(settings.get('promoCodes', []))}, "
        f"отелей добавлено: {added_hotels} (в базе было {hotels_total})"
    )


def main() -> None:
    parser = argparse.ArgumentParser(prog="python -m app.cli")
    sub = parser.add_subparsers(dest="command", required=True)

    owner = sub.add_parser("create-owner", help="создать владельца с паролем для админки")
    owner.add_argument("--phone", required=True)
    owner.add_argument("--password", required=True)
    owner.add_argument("--name")

    seed = sub.add_parser("seed-content", help="перенести content/*.json и фото в базу")
    seed.add_argument("--content", type=Path, default=WORKSPACE / "content")
    seed.add_argument("--photos", type=Path, default=WORKSPACE / "client_app" / "assets" / "content" / "photos")

    sub.add_parser("make-thumbs", help="создать превью для уже загруженных фото (локальное хранилище)")

    args = parser.parse_args()
    if args.command == "create-owner":
        asyncio.run(create_owner(args.phone, args.password, args.name))
    elif args.command == "make-thumbs":
        from app.core.config import get_settings

        make_thumbs(Path(get_settings().media_dir))
    else:
        asyncio.run(seed_content(args.content, args.photos))


if __name__ == "__main__":
    main()
