"""Иконки TUR TUK для web-сборки: бордовый скруглённый квадрат с «TT».

Настоящего логотипа нет — файл, который присылала заказчица, не читается
(лежит в brief.unreadable). Это знак-заглушка в фирменном цвете, чтобы
приложение, добавленное на домашний экран iPhone, не выглядело безымянной
серой плиткой. Придёт логотип — меняются только эти PNG.
"""

from PIL import Image, ImageDraw, ImageFont
from pathlib import Path

ACCENT = (139, 0, 0, 255)
WHITE = (255, 255, 255, 255)


def font(size: int):
    for name in ("arialbd.ttf", "seguibl.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def draw_icon(size: int, maskable: bool) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # maskable-иконку система обрезает по своей маске, поэтому фон заливаем
    # на весь квадрат, а знак ужимаем в безопасную зону.
    if maskable:
        d.rectangle([0, 0, size, size], fill=ACCENT)
        text_size = int(size * 0.34)
    else:
        d.rounded_rectangle([0, 0, size, size], radius=int(size * 0.22), fill=ACCENT)
        text_size = int(size * 0.42)

    f = font(text_size)
    box = d.textbbox((0, 0), "TT", font=f)
    d.text(
        ((size - box[2] - box[0]) / 2, (size - box[3] - box[1]) / 2),
        "TT",
        font=f,
        fill=WHITE,
    )
    return img


def main() -> None:
    for app in ("client_app", "courier_app"):
        out = Path(__file__).resolve().parents[1] / app / "web"
        (out / "icons").mkdir(parents=True, exist_ok=True)
        for size in (192, 512):
            draw_icon(size, maskable=False).save(out / "icons" / f"Icon-{size}.png")
            draw_icon(size, maskable=True).save(out / "icons" / f"Icon-maskable-{size}.png")
        draw_icon(64, maskable=False).save(out / "favicon.png")
        print(f"{app}: 5 файлов")


if __name__ == "__main__":
    main()
