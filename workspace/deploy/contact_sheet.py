"""Контактный лист демо-фотографий: все снимки одной картинкой с подписями.

Нужен, чтобы за один взгляд увидеть, где подобранное фото не совпало со
смыслом товара (loremflickr при отсутствии совпадений отдаёт случайный
кадр), и перекачать только эти позиции.

Запуск: python workspace/deploy/contact_sheet.py
Результат: workspace/deploy/dist/_photos.jpg
"""

import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "client_app" / "assets" / "demo"
OUT = ROOT / "deploy" / "dist" / "_photos.jpg"
DEMO = ROOT / "client_app" / "lib" / "core" / "demo" / "demo_data.dart"

CELL = 220
COLS = 6
LABEL = 34


def names() -> dict[str, str]:
    """Достаём названия товаров из демо-данных, чтобы подпись была осмысленной."""
    text = DEMO.read_text(encoding="utf-8")
    pairs = re.findall(
        r"name:\s*'([^']{3,60})'.{0,600}?imageAsset:\s*'assets/demo/(p\d\d)\.jpg'",
        text,
        re.S,
    )
    return {asset: name for name, asset in pairs}


def font(size: int):
    for candidate in ("arial.ttf", "segoeui.ttf"):
        try:
            return ImageFont.truetype(candidate, size)
        except OSError:
            continue
    return ImageFont.load_default()


def main() -> None:
    files = sorted(SRC.glob("*.jpg"))
    titles = names()
    rows = (len(files) + COLS - 1) // COLS

    sheet = Image.new("RGB", (COLS * CELL, rows * (CELL + LABEL)), "white")
    draw = ImageDraw.Draw(sheet)
    f = font(13)

    for i, path in enumerate(files):
        x = (i % COLS) * CELL
        y = (i // COLS) * (CELL + LABEL)

        img = Image.open(path).convert("RGB").resize((CELL, CELL))
        sheet.paste(img, (x, y))

        stem = path.stem
        caption = f"{stem}  {titles.get(stem, '')}"[:34]
        draw.rectangle([x, y + CELL, x + CELL, y + CELL + LABEL], fill="#F0F0F0")
        draw.text((x + 6, y + CELL + 9), caption, fill="#111111", font=f)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT, quality=88)
    print(f"{len(files)} фото -> {OUT}")


if __name__ == "__main__":
    main()
