"""Загрузка фото товара и фото коробки: `upload_file()` с моком S3-клиента
(без сети и без выбранного провайдера — тот же принцип, что `FakeSmsProvider`
в `conftest.py` для SMS) плюс сквозные тесты обоих эндпоинтов.

Реальный Postgres, тот же контур, что у остальных тестов проекта — мокается
только сеть до S3, ровно то, что просит формулировка задачи.
"""

from contextlib import asynccontextmanager
from io import BytesIO

import pytest
import pytest_asyncio
from fastapi import HTTPException, UploadFile
from httpx import AsyncClient
from sqlalchemy import delete, select
from starlette.datastructures import Headers

import app.services.storage as storage
from app.core.security import create_access_token
from app.db.session import async_session_factory
from app.models.category import Category
from app.models.order import Order, OrderStatus
from app.models.product import Product
from app.models.role import Role, RoleCode
from app.models.user import User

TEST_PHONE_PREFIX = "+70004"
TEST_PREFIX = "TestS3_"


class FakeS3Client:
    """Мок S3-клиента: помнит все `put_object` без похода в сеть."""

    def __init__(self) -> None:
        self.put_calls: list[dict] = []

    async def put_object(self, **kwargs) -> dict:
        self.put_calls.append(kwargs)
        return {"ETag": '"fake-etag"'}


@pytest.fixture
def fake_s3(monkeypatch):
    client = FakeS3Client()

    @asynccontextmanager
    async def _fake_s3_client():
        yield client

    # Патчим имя внутри app.services.storage, а не app.core.s3: storage.py
    # импортировал `s3_client` себе в модуль, оригинал в core трогать незачем.
    monkeypatch.setattr(storage, "s3_client", _fake_s3_client)
    # Без S3_ENDPOINT_URL/S3_BUCKET store_image пишет на диск — здесь проверяем ветку S3.
    monkeypatch.setattr(storage, "_s3_configured", lambda: True)
    return client


def _png_bytes() -> bytes:
    """Настоящая картинка: store_image открывает файл Pillow и пережимает в WebP."""
    from PIL import Image

    buf = BytesIO()
    Image.new("RGB", (40, 30), (139, 0, 0)).save(buf, format="PNG")
    return buf.getvalue()


REAL_IMAGE = _png_bytes()


def _upload_file(name: str, content_type: str, data: bytes = b"fake-image-bytes") -> UploadFile:
    return UploadFile(
        file=BytesIO(data), filename=name, headers=Headers({"content-type": content_type})
    )


async def _wipe_s3_test_data() -> None:
    async with async_session_factory() as session:
        user_ids = select(User.id).where(User.phone.like(f"{TEST_PHONE_PREFIX}%"))
        await session.execute(delete(Order).where(Order.user_id.in_(user_ids)))
        await session.execute(delete(Order).where(Order.courier_id.in_(user_ids)))
        await session.execute(delete(User).where(User.phone.like(f"{TEST_PHONE_PREFIX}%")))

        category_ids = select(Category.id).where(Category.name.like(f"{TEST_PREFIX}%"))
        await session.execute(delete(Product).where(Product.category_id.in_(category_ids)))
        await session.execute(delete(Category).where(Category.name.like(f"{TEST_PREFIX}%")))
        await session.commit()


@pytest_asyncio.fixture(autouse=True)
async def _cleanup_s3_data():
    await _wipe_s3_test_data()
    yield
    await _wipe_s3_test_data()


async def _make_user(role_code: str, suffix: str) -> tuple[User, str]:
    async with async_session_factory() as session:
        result = await session.execute(select(Role).where(Role.code == role_code))
        role = result.scalar_one()
        user = User(phone=f"{TEST_PHONE_PREFIX}{suffix}", role_id=role.id)
        session.add(user)
        await session.commit()
        await session.refresh(user)
    return user, create_access_token(user.id)


async def _make_category(name: str) -> Category:
    async with async_session_factory() as session:
        category = Category(name=f"{TEST_PREFIX}{name}")
        session.add(category)
        await session.commit()
        await session.refresh(category)
    return category


async def _make_product(name: str, category_id: int) -> Product:
    async with async_session_factory() as session:
        product = Product(name=f"{TEST_PREFIX}{name}", price=500, category_id=category_id)
        session.add(product)
        await session.commit()
        await session.refresh(product)
    return product


async def _make_order(*, user_id: int, courier_id: int | None = None) -> Order:
    async with async_session_factory() as session:
        order = Order(
            user_id=user_id,
            courier_id=courier_id,
            status=OrderStatus.DELIVERING,
            total=3500,
            hotel_name="Test Hotel",
            room_number="101",
        )
        session.add(order)
        await session.commit()
        await session.refresh(order)
    return order


def _auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


# --- upload_file(): unit-уровень, S3 замокан --------------------------------


async def test_upload_file_calls_put_object_and_returns_url(fake_s3):
    file = _upload_file("photo.jpg", "image/jpeg")

    url = await storage.upload_file(file, "test-bucket", "products/1/abc.jpg")

    assert len(fake_s3.put_calls) == 1
    call = fake_s3.put_calls[0]
    assert call["Bucket"] == "test-bucket"
    assert call["Key"] == "products/1/abc.jpg"
    assert call["Body"] == b"fake-image-bytes"
    assert call["ContentType"] == "image/jpeg"
    assert url.endswith("/test-bucket/products/1/abc.jpg")


def test_validate_image_type_accepts_jpeg_and_png():
    storage.validate_image_type(_upload_file("a.jpg", "image/jpeg"))
    storage.validate_image_type(_upload_file("a.png", "image/png"))


def test_validate_image_type_rejects_other_mime():
    with pytest.raises(HTTPException) as exc_info:
        storage.validate_image_type(_upload_file("a.gif", "image/gif"))
    assert exc_info.value.status_code == 415


def test_build_key_includes_all_parts_and_extension():
    key = storage.build_key("products", "42", content_type="image/png")
    assert key.startswith("products/42/")
    assert key.endswith(".png")


# --- POST /api/admin/products/{id}/photo ----------------------------------------


async def test_admin_upload_product_photo_sets_url(client: AsyncClient, fake_s3):
    _, token = await _make_user(RoleCode.ADMIN.value, "01")
    category = await _make_category("Category01")
    product = await _make_product("Product01", category.id)

    resp = await client.post(
        f"/api/admin/products/{product.id}/photo",
        headers=_auth(token),
        files={"file": ("photo.jpg", REAL_IMAGE, "image/jpeg")},
    )

    assert resp.status_code == 200
    body = resp.json()
    assert body["photo_url"]
    assert len(fake_s3.put_calls) == 1
    # Любой входной формат хранится пережатым в WebP.
    assert fake_s3.put_calls[0]["ContentType"] == "image/webp"


async def test_admin_upload_product_photo_rejects_bad_mime(client: AsyncClient, fake_s3):
    _, token = await _make_user(RoleCode.ADMIN.value, "02")
    category = await _make_category("Category02")
    product = await _make_product("Product02", category.id)

    resp = await client.post(
        f"/api/admin/products/{product.id}/photo",
        headers=_auth(token),
        files={"file": ("photo.gif", b"gif-bytes", "image/gif")},
    )

    assert resp.status_code == 415
    assert fake_s3.put_calls == []


async def test_admin_upload_product_photo_unknown_product_is_404(client: AsyncClient, fake_s3):
    _, token = await _make_user(RoleCode.ADMIN.value, "03")

    resp = await client.post(
        "/api/admin/products/999999999/photo",
        headers=_auth(token),
        files={"file": ("photo.jpg", b"fake-image-bytes", "image/jpeg")},
    )

    assert resp.status_code == 404


async def test_client_cannot_upload_product_photo(client: AsyncClient, fake_s3):
    _, token = await _make_user(RoleCode.CLIENT.value, "04")
    category = await _make_category("Category04")
    product = await _make_product("Product04", category.id)

    resp = await client.post(
        f"/api/admin/products/{product.id}/photo",
        headers=_auth(token),
        files={"file": ("photo.jpg", b"fake-image-bytes", "image/jpeg")},
    )

    assert resp.status_code == 403
    assert fake_s3.put_calls == []


# --- POST /orders/{id}/delivery-photo ---------------------------------------


async def test_courier_upload_delivery_photo_sets_url(client: AsyncClient, fake_s3):
    courier, token = await _make_user(RoleCode.COURIER.value, "10")
    order = await _make_order(user_id=courier.id, courier_id=courier.id)

    resp = await client.post(
        f"/orders/{order.id}/delivery-photo",
        headers=_auth(token),
        files={"file": ("box.png", REAL_IMAGE, "image/png")},
    )

    assert resp.status_code == 200
    body = resp.json()
    assert body["delivery_photo_url"]
    assert len(fake_s3.put_calls) == 1
    assert fake_s3.put_calls[0]["ContentType"] == "image/webp"


async def test_courier_upload_delivery_photo_rejects_bad_mime(client: AsyncClient, fake_s3):
    courier, token = await _make_user(RoleCode.COURIER.value, "11")
    order = await _make_order(user_id=courier.id, courier_id=courier.id)

    resp = await client.post(
        f"/orders/{order.id}/delivery-photo",
        headers=_auth(token),
        files={"file": ("box.txt", b"not-an-image", "text/plain")},
    )

    assert resp.status_code == 415
    assert fake_s3.put_calls == []


async def test_courier_cannot_upload_photo_for_other_couriers_order(client: AsyncClient, fake_s3):
    courier_a, token_a = await _make_user(RoleCode.COURIER.value, "12")
    courier_b, _ = await _make_user(RoleCode.COURIER.value, "13")
    client_user, _ = await _make_user(RoleCode.CLIENT.value, "14")
    order = await _make_order(user_id=client_user.id, courier_id=courier_b.id)

    resp = await client.post(
        f"/orders/{order.id}/delivery-photo",
        headers=_auth(token_a),
        files={"file": ("box.jpg", b"box-bytes", "image/jpeg")},
    )

    assert resp.status_code == 403
    assert fake_s3.put_calls == []


async def test_client_cannot_upload_delivery_photo(client: AsyncClient, fake_s3):
    client_user, token = await _make_user(RoleCode.CLIENT.value, "15")
    order = await _make_order(user_id=client_user.id)

    resp = await client.post(
        f"/orders/{order.id}/delivery-photo",
        headers=_auth(token),
        files={"file": ("box.jpg", b"box-bytes", "image/jpeg")},
    )

    assert resp.status_code == 403
    assert fake_s3.put_calls == []


async def test_delivery_photo_unknown_order_is_404(client: AsyncClient, fake_s3):
    courier, token = await _make_user(RoleCode.COURIER.value, "16")

    resp = await client.post(
        "/orders/999999999/delivery-photo",
        headers=_auth(token),
        files={"file": ("box.jpg", b"box-bytes", "image/jpeg")},
    )

    assert resp.status_code == 404
