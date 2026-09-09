"""Загрузка файлов в S3-совместимое хранилище.

Единая точка правды для `upload_file` — и админка (фото товара), и
курьерское приложение (фото коробки на рецепции) вызывают одну и ту же
функцию поверх `app.core.s3.s3_client`, а не дублируют `put_object` в
каждом роутере.
"""

from uuid import uuid4

from fastapi import HTTPException, UploadFile, status

from app.core.config import get_settings
from app.core.s3 import s3_client

# Ровно то, что просит задача — image/jpeg и image/png. Список закрытый:
# бриф про фото товара и фото коробки не называет другие форматы.
ALLOWED_CONTENT_TYPES: dict[str, str] = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
}


def validate_image_type(file: UploadFile) -> None:
    """MIME-тип берётся из заголовка multipart-части, не из имени файла —
    расширение в имени клиент может выставить любое.
    """
    if file.content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=(
                f"недопустимый тип файла: {file.content_type!r}; "
                "ожидается image/jpeg или image/png"
            ),
        )


def build_key(*parts: str, content_type: str) -> str:
    """Ключ вида `products/42/<uuid>.jpg` — случайный суффикс, чтобы повторная
    загрузка не перетирала объект под тем же именем молча (историю прошлых
    фото S3 не ведёт, а версии никто не просил).
    """
    ext = ALLOWED_CONTENT_TYPES[content_type]
    return "/".join([*parts, f"{uuid4().hex}{ext}"])


async def upload_file(file: UploadFile, bucket: str, key: str) -> str:
    """Загружает файл в S3 и возвращает URL объекта.

    URL строится из `S3_ENDPOINT_URL` + bucket + key: конкретный провайдер
    (Selectel/Яндекс/иной) владелец не выбрал (см. `app/core/s3.py`), поэтому
    здесь нет ничего специфичного для одного облака вроде подписанных ссылок.
    """
    body = await file.read()
    async with s3_client() as client:
        await client.put_object(
            Bucket=bucket,
            Key=key,
            Body=body,
            ContentType=file.content_type,
        )
    endpoint = (get_settings().s3_endpoint_url or "").rstrip("/")
    return f"{endpoint}/{bucket}/{key}"
