"""Хранение картинок: фото товаров, логотип, фото коробки от курьера.

Единая точка правды — `store_image()`. Она проверяет тип, пережимает фото
(длинная сторона не больше `MAX_SIDE`, WebP), и кладёт результат:

* в S3-совместимое хранилище, если заданы `S3_ENDPOINT_URL` и `S3_BUCKET`;
* иначе — на диск в `MEDIA_DIR`, откуда `app.main` раздаёт его по `/media/…`.

Локальный режим нужен, пока провайдер S3 не выбран: админка и приложение
работают сразу, а переезд в S3 — это две переменные окружения.
"""

from __future__ import annotations

import io
from pathlib import Path
from uuid import uuid4

from fastapi import HTTPException, UploadFile, status
from PIL import Image, ImageOps, UnidentifiedImageError

from app.core.config import get_settings
from app.core.s3 import s3_client

ALLOWED_CONTENT_TYPES: dict[str, str] = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
}

MAX_SIDE = 1600
MAX_UPLOAD_BYTES = 15 * 1024 * 1024


def validate_image_type(file: UploadFile) -> None:
    """MIME-тип берётся из заголовка multipart-части, не из имени файла."""
    if file.content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=(
                f"недопустимый тип файла: {file.content_type!r}; "
                "ожидается JPEG, PNG или WebP"
            ),
        )


def build_key(*parts: str, content_type: str) -> str:
    """Ключ вида `products/42/<uuid>.jpg` — случайный суффикс, чтобы повторная
    загрузка не перетирала прошлый файл под тем же именем."""
    ext = ALLOWED_CONTENT_TYPES[content_type]
    return "/".join([*parts, f"{uuid4().hex}{ext}"])


def process_image(raw: bytes, *, keep_alpha: bool = False) -> tuple[bytes, str]:
    """Поворачивает по EXIF, уменьшает до `MAX_SIDE`, убирает метаданные и
    сохраняет в WebP. Возвращает (байты, content-type)."""
    try:
        image = Image.open(io.BytesIO(raw))
        image = ImageOps.exif_transpose(image)
    except (UnidentifiedImageError, OSError) as exc:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail="файл не похож на картинку",
        ) from exc

    has_alpha = image.mode in ("RGBA", "LA") or "transparency" in image.info
    image = image.convert("RGBA" if (keep_alpha and has_alpha) else "RGB")
    image.thumbnail((MAX_SIDE, MAX_SIDE), Image.LANCZOS)

    out = io.BytesIO()
    image.save(out, format="WEBP", quality=82, method=4)
    return out.getvalue(), "image/webp"


def _s3_configured() -> bool:
    settings = get_settings()
    return bool(settings.s3_endpoint_url and settings.s3_bucket)


async def upload_file(file: UploadFile, bucket: str, key: str) -> str:
    """Низкоуровневая загрузка файла как есть в S3; возвращает URL объекта."""
    body = await file.read()
    return await _put_s3(body, file.content_type or "application/octet-stream", bucket, key)


async def _put_s3(body: bytes, content_type: str, bucket: str, key: str) -> str:
    async with s3_client() as client:
        await client.put_object(Bucket=bucket, Key=key, Body=body, ContentType=content_type)
    endpoint = (get_settings().s3_endpoint_url or "").rstrip("/")
    return f"{endpoint}/{bucket}/{key}"


def _put_local(body: bytes, key: str) -> str:
    path = Path(get_settings().media_dir) / key
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(body)
    return f"/media/{key}"


async def store_image(file: UploadFile, *parts: str, keep_alpha: bool = False) -> str:
    """Проверить, пережать и сохранить картинку. Возвращает URL: абсолютный
    для S3 или `/media/...` для локального хранилища (см. `absolute_url`)."""
    validate_image_type(file)
    raw = await file.read()
    if len(raw) > MAX_UPLOAD_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="файл больше 15 МБ",
        )
    body, content_type = process_image(raw, keep_alpha=keep_alpha)
    key = "/".join([*parts, f"{uuid4().hex}.webp"])
    if _s3_configured():
        return await _put_s3(body, content_type, get_settings().s3_bucket, key)
    return _put_local(body, key)


def absolute_url(url: str | None, base_url: str) -> str:
    """`/media/...` → полный адрес для мобильного приложения. Абсолютные
    ссылки (S3, внешние) возвращаются как есть."""
    if not url:
        return ""
    if url.startswith(("http://", "https://")):
        return url
    public = get_settings().public_base_url
    root = (public or base_url).rstrip("/")
    return f"{root}{url}"
