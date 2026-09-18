"""Экспорт демо-каталога из Dart-литералов в JSON настроек.

Одноразовый инструмент: до этого 30 товаров, категории и промокоды жили
прямо в `demo_data.dart`. Чтобы заказчица могла прислать свой каталог, а мы
его просто подключили, контент переезжает в `workspace/content/*.json`.

Скрипт вытаскивает то, что уже написано, и складывает в JSON — руками
тридцать карточек не перенабирают.

Запуск: python workspace/tools/export_demo_to_content.py
"""

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEMO = ROOT / "client_app" / "lib" / "core" / "demo" / "demo_data.dart"
OUT = ROOT / "content"

ICONS = {1: "gift", 2: "spa", 3: "basket", 4: "cafe", 5: "cake", 6: "beach"}


def dart_string(raw: str) -> str:
    """Склеивает соседние строковые литералы Dart в одну строку."""
    parts = re.findall(r"'((?:[^'\\]|\\.)*)'", raw, re.S)
    return "".join(parts).replace("\\'", "'").replace("\\n", " ").strip()


def field(block: str, name: str) -> str | None:
    pattern = rf"\b{name}:\s*(.+?)(?=,\s*\n\s*[a-zA-Z]+:|,?\s*$)"
    m = re.search(pattern, block, re.S)
    return m.group(1).strip() if m else None


def main() -> None:
    text = DEMO.read_text(encoding="utf-8")

    categories = [
        {"id": int(cid), "name": name, "icon": ICONS.get(int(cid), "basket")}
        for cid, name in re.findall(r"Category\(id:\s*(\d+),\s*name:\s*'([^']+)'", text)
    ]

    products = []
    for block in re.split(r"\n\s*Product\(", text)[1:]:
        block = block.split("\n        ),")[0]

        pid = field(block, "id")
        if not pid or not pid.strip().isdigit():
            continue

        cat = field(block, "categoryId") or ""
        price = field(block, "price") or "0"
        old = field(block, "oldPrice")
        available = field(block, "isAvailable")
        asset = dart_string(field(block, "imageAsset") or "")

        products.append(
            {
                "id": int(pid),
                "sku": f"p{int(pid):02d}",
                "categoryId": int(cat) if cat.strip().isdigit() else None,
                "name": dart_string(field(block, "name") or ""),
                "description": dart_string(field(block, "description") or ""),
                "price": float(price.rstrip(",")),
                "oldPrice": None if not old or old.strip() == "null" else float(old.rstrip(",")),
                "unit": dart_string(field(block, "unit") or ""),
                "photo": Path(asset).name,
                "isAvailable": (available or "").strip() != "false",
            }
        )

    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "catalog.json").write_text(
        json.dumps({"categories": categories, "products": products}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"категорий: {len(categories)}, товаров: {len(products)} -> {OUT / 'catalog.json'}")


if __name__ == "__main__":
    main()
