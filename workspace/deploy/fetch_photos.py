"""Фотографии демо-каталога с Викисклада, с проверкой попадания.

История вопроса: сначала картинки брались с loremflickr — при промахе по
тегам он молча отдаёт случайный кадр, и под «Магнитом Кемер» оказывался
голубь. Перешли на Викисклад, но и там поиск по описанию возвращает
соседнее по смыслу: под «джезвой» — прилавок с оберегами.

Поэтому здесь двойная защита: у каждого товара есть обязательные слова,
и файл принимается, только если его НАЗВАНИЕ содержит хотя бы одно из них.
Имя принятого файла печатается — по нему видно, что именно легло в витрину,
без разглядывания тридцати картинок.

Запуск: python workspace/deploy/fetch_photos.py
"""

import json
import time
import urllib.parse
import urllib.request
from pathlib import Path

API = "https://commons.wikimedia.org/w/api.php"
UA = "TurTukDemo/1.0 (demo catalogue images; contact: dev@example.com)"

# name: (поисковый запрос, обязательные слова, стоп-слова)
# Стоп-слова нужны потому, что попадание по обязательному слову ещё не значит
# попадание по смыслу: под запросом «halva» Викисклад отдал мороженое, а под
# «chocolate hazelnut» — восьмислойный торт.
QUERIES: dict[str, tuple[str, list[str], list[str]]] = {
    "p01": ("fridge magnet souvenir", ["magnet"], []),
    "p02": ("Iznik ceramic plate", ["iznik", "ceramic plate"], []),
    "p03": ("Turkish tea glass", ["tea glass", "çay", "cay bardag"], []),
    "p04": ("nazar boncuk evil eye bead", ["nazar", "evil eye"], []),
    "p05": ("cezve Turkish coffee pot", ["cezve", "ibrik", "jezve"], []),
    "p06": ("olive oil soap", ["soap"], []),
    "p07": ("rose water bottle", ["rose water", "rosewater"], []),
    "p08": ("Nigella sativa seeds oil", ["nigella", "black seed", "black cumin"], []),
    "p09": ("hand cream tube cosmetic", ["cream"], ["woman", "applying"]),
    "p10": ("hamam bath glove mitt", ["hamam", "hammam", "kese", "mitt", "glove", "loofah"], ["boxing"]),
    "p11": ("olive oil bottle", ["olive oil"], []),
    "p12": ("spices", ["spice", "baharat"], []),
    "p13": ("feta white cheese", ["cheese", "peynir", "feta"], []),
    "p14": ("olives bowl black", ["olive"], []),
    "p15": ("honey jar", ["honey"], []),
    "p16": ("ground coffee", ["coffee"], ["cup", "latte", "machine"]),
    "p17": ("pomegranate fruit", ["pomegranate"], []),
    "p18": ("dried black tea leaves", ["tea"], ["lipton", "mug", "cup", "bag"]),
    "p19": ("ayran drink", ["ayran", "yogurt drink", "yoghurt"], []),
    "p20": ("pomegranate juice glass", ["pomegranate juice", "juice"], []),
    "p21": ("Turkish delight lokum", ["lokum", "delight", "rahat"], []),
    "p22": ("baklava", ["baklava"], []),
    "p23": ("helva tahini sesame", ["halva", "helva"], ["icecream", "ice cream", "cake"]),
    "p24": ("pismaniye", ["pismaniye", "pişmaniye", "floss halva"], []),
    "p25": ("chocolate dragee candy", ["dragee", "chocolate"], ["cake", "bar", "drink"]),
    "p26": ("beach towel", ["towel"], ["paper", "rack"]),
    "p27": ("sunscreen", ["sunscreen", "sun cream", "sunblock", "sunburn"], []),
    "p28": ("snorkel diving mask", ["snorkel", "diving mask", "mask"], []),
    "p29": ("wicker basket straw bag", ["straw", "basket", "wicker"], ["chair", "ball", "roof"]),
    "p30": ("inflatable air mattress swimming", ["inflatable", "air mattress", "float"], []),
    "box01": ("cardboard box parcel", ["box", "parcel", "carton"], ["tv", "television", "set ("]),
}

OUT = Path(__file__).resolve().parents[1] / "client_app" / "assets" / "demo"
MIN_BYTES = 8_000
BAD_EXT = (".svg", ".pdf", ".tif", ".tiff", ".gif", ".webm", ".ogv")


def search(query: str, width: int) -> list[tuple[str, str]]:
    """[(название файла, ссылка на превью)] в порядке релевантности."""
    params = {
        "action": "query",
        "generator": "search",
        "gsrsearch": query,
        "gsrnamespace": "6",
        "gsrlimit": "30",
        "prop": "imageinfo",
        "iiprop": "url|mime",
        "iiurlwidth": str(width),
        "format": "json",
    }
    req = urllib.request.Request(
        f"{API}?{urllib.parse.urlencode(params)}", headers={"User-Agent": UA}
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = json.load(resp)

    pages = (data.get("query") or {}).get("pages") or {}
    # Поиск отдаёт страницы вперемешку — восстанавливаем порядок релевантности.
    ordered = sorted(pages.values(), key=lambda p: p.get("index", 999))

    out = []
    for page in ordered:
        title = (page.get("title") or "").removeprefix("File:")
        if title.lower().endswith(BAD_EXT):
            continue
        info = (page.get("imageinfo") or [{}])[0]
        thumb = info.get("thumburl")
        if thumb and str(info.get("mime", "")).startswith("image/"):
            out.append((title, thumb))
    return out


def download(url: str) -> bytes | None:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = resp.read()
    if len(data) >= MIN_BYTES and (data[:2] == b"\xff\xd8" or data[:4] == b"\x89PNG"):
        return data
    return None


def fetch(name: str) -> bool:
    query, must, block = QUERIES[name]
    width = 800 if name == "box01" else 600
    target = OUT / f"{name}.jpg"

    try:
        candidates = search(query, width)
    except Exception as exc:  # noqa: BLE001
        print(f"{name}: поиск упал — {exc}")
        return False

    for title, url in candidates:
        low = title.lower()
        if not any(word in low for word in must):
            continue
        if any(word in low for word in block):
            continue
        try:
            data = download(url)
        except Exception:  # noqa: BLE001
            continue
        if data:
            target.write_bytes(data)
            print(f"{name}: {title[:60]}")
            return True

    print(f"{name}: ПРОМАХ ({query}) — прежнее фото оставлено")
    return False


def main() -> None:
    import sys

    OUT.mkdir(parents=True, exist_ok=True)
    # Без аргументов — все товары; с аргументами — только названные,
    # чтобы переспрашивать промахи, не трогая уже удачные снимки.
    wanted = [a for a in sys.argv[1:] if a in QUERIES] or list(QUERIES)
    ok = 0
    for name in wanted:
        ok += fetch(name)
        time.sleep(0.3)
    print(f"\nОбновлено {ok} из {len(wanted)}")


if __name__ == "__main__":
    main()
