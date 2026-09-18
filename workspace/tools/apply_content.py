"""Применение контента: `workspace/content` → приложения.

Смысл: всё, что присылает заказчица — товары, описания, цены, фотографии,
список отелей, промокоды, суммы доставки, контакты — лежит в одном месте,
в `workspace/content`. Приложения не хранят этого у себя, они читают
подготовленные файлы из своих ассетов.

Что делает скрипт:
1. проверяет JSON на осмысленность и печатает, чего не хватает;
2. переименовывает и раскладывает фотографии по SKU;
3. кладёт готовые файлы в `client_app/assets/content`;
4. сообщает, что осталось получить от заказчицы.

Как подключать новый каталог:
    1. положить фотографии в workspace/content/photos (имя = SKU товара,
       например p07.jpg);
    2. поправить workspace/content/catalog.json, settings.json, hotels.json;
    3. python workspace/tools/apply_content.py
    4. пересобрать приложение.

Запуск с --check — только проверка, без копирования.
"""

import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "content"
PHOTOS = CONTENT / "photos"
TARGET = ROOT / "client_app" / "assets" / "content"

PLACEHOLDER_PHOTOS = ROOT / "client_app" / "assets" / "demo"


def load(name: str) -> dict:
    path = CONTENT / name
    if not path.exists():
        raise SystemExit(f"НЕТ ФАЙЛА: {path}")
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"{name}: битый JSON — {exc}") from exc


def check_catalog(catalog: dict) -> list[str]:
    problems = []
    ids = [p["id"] for p in catalog["products"]]
    if len(ids) != len(set(ids)):
        problems.append("каталог: повторяются id товаров")

    cat_ids = {c["id"] for c in catalog["categories"]}
    for p in catalog["products"]:
        tag = f"{p.get('sku') or p['id']} «{p.get('name', '')[:30]}»"
        if not p.get("name"):
            problems.append(f"{tag}: нет названия")
        if not p.get("description"):
            problems.append(f"{tag}: нет описания")
        if not p.get("price"):
            problems.append(f"{tag}: нет цены")
        if p.get("categoryId") not in cat_ids:
            problems.append(f"{tag}: категория {p.get('categoryId')} не найдена")
        if p.get("oldPrice") and p["oldPrice"] <= p["price"]:
            problems.append(f"{tag}: старая цена не больше новой")
    return problems


def check_settings(settings: dict) -> list[str]:
    missing = []
    contacts = settings.get("contacts", {})
    for key, human in (
        ("phone", "телефон поддержки"),
        ("privacyPolicyUrl", "ссылка на политику конфиденциальности"),
        ("supportUrl", "страница поддержки"),
    ):
        if not contacts.get(key):
            missing.append(f"настройки: не заполнен {human}")
    if not settings.get("brand", {}).get("logoFile"):
        missing.append("настройки: не приложен логотип (brand.logoFile)")
    return missing


def resolve_photos(catalog: dict) -> tuple[list[tuple[Path, str]], list[str]]:
    """Ищет фото каждого товара: сначала присланные, потом временные."""
    plan: list[tuple[Path, str]] = []
    missing: list[str] = []

    for product in catalog["products"]:
        sku = product.get("sku") or f"p{product['id']:02d}"
        wanted = product.get("photo") or f"{sku}.jpg"

        candidates = [PHOTOS / wanted, PHOTOS / f"{sku}.jpg", PHOTOS / f"{sku}.png"]
        source = next((c for c in candidates if c.exists()), None)

        if source is None:
            # Временная картинка, чтобы витрина не зияла дырами до присылки фото.
            fallback = PLACEHOLDER_PHOTOS / f"{sku}.jpg"
            if fallback.exists():
                source = fallback
                missing.append(f"{sku} «{product.get('name', '')[:30]}»")
            else:
                missing.append(f"{sku} — фото нет вообще")
                continue

        plan.append((source, f"{sku}.jpg"))
        product["photo"] = f"{sku}.jpg"

    return plan, missing


def main() -> None:
    check_only = "--check" in sys.argv

    settings = load("settings.json")
    hotels = load("hotels.json")
    catalog = load("catalog.json")

    problems = check_catalog(catalog)
    todo = check_settings(settings)
    plan, missing_photos = resolve_photos(catalog)

    active_hotels = [h for h in hotels["hotels"] if h.get("active", True)]
    print(f"Категорий: {len(catalog['categories'])}")
    print(f"Товаров: {len(catalog['products'])}")
    print(f"Отелей активных: {len(active_hotels)} из {len(hotels['hotels'])}")
    print(f"Промокодов: {len(settings.get('promoCodes', []))}")

    if problems:
        print("\nОШИБКИ В КАТАЛОГЕ (исправить до сборки):")
        for p in problems:
            print(f"  • {p}")

    if missing_photos:
        print(f"\nНЕТ ФОТО ОТ ЗАКАЗЧИЦЫ ({len(missing_photos)}), стоят временные:")
        for m in missing_photos[:10]:
            print(f"  • {m}")
        if len(missing_photos) > 10:
            print(f"  • …ещё {len(missing_photos) - 10}")

    if todo:
        print("\nЖДЁМ ОТ ЗАКАЗЧИЦЫ:")
        for t in todo:
            print(f"  • {t}")

    if check_only:
        print("\n(только проверка, файлы не тронуты)")
        return

    if problems:
        raise SystemExit("\nСборка контента остановлена: сначала исправить ошибки каталога.")

    target_photos = TARGET / "photos"
    target_photos.mkdir(parents=True, exist_ok=True)
    for source, name in plan:
        shutil.copy2(source, target_photos / name)

    for name, payload in (
        ("settings.json", settings),
        ("hotels.json", hotels),
        ("catalog.json", catalog),
    ):
        (TARGET / name).write_text(
            json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8"
        )

    print(f"\nГотово: {len(plan)} фото и 3 файла настроек -> {TARGET}")
    print("Дальше: flutter build (или flutter run) — приложение подхватит новый контент.")


if __name__ == "__main__":
    main()
