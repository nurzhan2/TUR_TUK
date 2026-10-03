"""Веб-админка и связка «админка → /app/config → заказ».

Проверяет главное обещание: всё, что владелец меняет в админке (товары,
цены, фото, отели, суммы доставки, промокоды), сразу видно приложению через
`GET /app/config`, а сервер считает заказ по тем же суммам.
"""

from io import BytesIO

import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from PIL import Image
from sqlalchemy import delete, select

from app.core.passwords import hash_password
from app.core.security import create_access_token
from app.db.session import async_session_factory
from app.main import app
from app.models.app_setting import AppSetting
from app.models.category import Category
from app.models.hotel import Hotel
from app.models.order import Order, OrderStatus
from app.models.order_status_log import OrderStatusLog
from app.models.product import Product
from app.models.promo_code import PromoCode
from app.models.role import Role, RoleCode
from app.models.user import User
from tests.conftest import TEST_PHONE_PREFIX, cleanup_test_users

P = "ZZADM "  # префикс тестовых записей
OWNER_PHONE = f"{TEST_PHONE_PREFIX}990001"
PASSWORD = "secret-pass-1"


def _png() -> bytes:
    buf = BytesIO()
    Image.new("RGB", (64, 48), (200, 30, 30)).save(buf, format="PNG")
    return buf.getvalue()


async def _wipe() -> None:
    async with async_session_factory() as s:
        user_ids = select(User.id).where(User.phone.like(f"{TEST_PHONE_PREFIX}99%"))
        order_ids = select(Order.id).where(Order.user_id.in_(user_ids))
        await s.execute(delete(OrderStatusLog).where(OrderStatusLog.order_id.in_(order_ids)))
        await s.execute(delete(Order).where(Order.user_id.in_(user_ids)))
        cat_ids = select(Category.id).where(Category.name.like(f"{P}%"))
        await s.execute(delete(Product).where(Product.category_id.in_(cat_ids)))
        await s.execute(delete(Category).where(Category.name.like(f"{P}%")))
        await s.execute(delete(Hotel).where(Hotel.name.like(f"{P}%")))
        await s.execute(delete(PromoCode).where(PromoCode.code.like("ZZADM%")))
        await s.execute(delete(User).where(User.phone.like(f"{TEST_PHONE_PREFIX}99%")))
        await s.commit()


@pytest_asyncio.fixture(autouse=True)
async def _clean_and_restore_settings():
    await _wipe()
    async with async_session_factory() as s:
        row = await s.get(AppSetting, 1)
        saved = dict(row.data) if row else {}
    yield
    try:
        await cleanup_test_users(f"{TEST_PHONE_PREFIX}99")
        await _wipe()
    finally:
        async with async_session_factory() as s:
            row = await s.get(AppSetting, 1)
            if row is not None:
                row.data = saved
                await s.commit()


async def _make_user(phone: str, role_code: str, password: str | None = None) -> User:
    async with async_session_factory() as s:
        role = (await s.execute(select(Role).where(Role.code == role_code))).scalar_one()
        user = User(phone=phone, name="Тест", role_id=role.id,
                    password_hash=hash_password(password) if password else None)
        s.add(user)
        await s.commit()
        await s.refresh(user)
        return user


@pytest_asyncio.fixture
async def admin_client() -> AsyncClient:
    await _make_user(OWNER_PHONE, RoleCode.OWNER.value, PASSWORD)
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        resp = await ac.post("/admin/login", data={"phone": OWNER_PHONE, "password": PASSWORD})
        assert resp.status_code == 302
        yield ac


@pytest_asyncio.fixture
async def anon() -> AsyncClient:
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        yield ac


# --- вход и доступ ----------------------------------------------------------


async def test_login_wrong_password_is_400(anon: AsyncClient):
    await _make_user(OWNER_PHONE, RoleCode.OWNER.value, PASSWORD)
    resp = await anon.post("/admin/login", data={"phone": OWNER_PHONE, "password": "nope-nope"})
    assert resp.status_code == 400
    assert "admin_token" not in resp.cookies


async def test_client_role_cannot_enter_admin(anon: AsyncClient):
    phone = f"{TEST_PHONE_PREFIX}990002"
    await _make_user(phone, RoleCode.CLIENT.value, PASSWORD)
    resp = await anon.post("/admin/login", data={"phone": phone, "password": PASSWORD})
    assert resp.status_code == 400


async def test_phone_format_is_normalized(anon: AsyncClient):
    await _make_user(OWNER_PHONE, RoleCode.OWNER.value, PASSWORD)
    pretty = "+7 (000) 099-00-01"  # те же цифры, что OWNER_PHONE
    resp = await anon.post("/admin/login", data={"phone": pretty, "password": PASSWORD})
    assert resp.status_code == 302


async def test_every_admin_page_requires_login(anon: AsyncClient):
    for path in ("/admin/", "/admin/orders", "/admin/products", "/admin/products/new",
                 "/admin/categories", "/admin/hotels", "/admin/hotels/import",
                 "/admin/promo", "/admin/settings", "/admin/staff"):
        resp = await anon.get(path)
        assert resp.status_code == 302, path
        assert resp.headers["location"].startswith("/admin/login"), path


async def test_all_pages_render_for_owner(admin_client: AsyncClient):
    for path in ("/admin/", "/admin/orders", "/admin/products", "/admin/products/new",
                 "/admin/categories", "/admin/hotels", "/admin/hotels/new", "/admin/hotels/import",
                 "/admin/promo", "/admin/promo/new", "/admin/settings", "/admin/staff"):
        resp = await admin_client.get(path)
        # /products/new без категорий уводит на страницу категорий
        assert resp.status_code in (200, 302), path
        if resp.status_code == 200:
            assert "TUR TUK" in resp.text, path


async def test_logout_clears_cookie(admin_client: AsyncClient):
    resp = await admin_client.post("/admin/logout")
    assert resp.status_code == 302
    admin_client.cookies.clear()
    assert (await admin_client.get("/admin/")).status_code == 302


# --- товары → /app/config ---------------------------------------------------


async def _create_category(ac: AsyncClient, name: str) -> Category:
    resp = await ac.post("/admin/categories", data={"name": f"{P}{name}", "icon": "gift", "sort_order": "5"})
    assert resp.status_code == 302
    async with async_session_factory() as s:
        return (await s.execute(select(Category).where(Category.name == f"{P}{name}"))).scalar_one()


async def test_product_from_admin_appears_in_app_config(admin_client: AsyncClient, tmp_path, monkeypatch):
    category = await _create_category(admin_client, "Сувениры")

    resp = await admin_client.post(
        "/admin/products/new",
        data={"name": f"{P}Магнит", "description": "Керамика", "price": "390", "old_price": "520",
              "unit": "шт", "sku": "ZZ01", "category_id": str(category.id), "sort_order": "1",
              "is_available": "on"},
        files={"photo": ("m.png", _png(), "image/png")},
    )
    assert resp.status_code == 302

    config = (await admin_client.get("/app/config")).json()
    product = next(p for p in config["products"] if p["name"] == f"{P}Магнит")
    assert product["price"] == 390
    assert product["oldPrice"] == 520
    assert product["unit"] == "шт"
    assert product["photoUrl"].startswith("http://test/media/products/")
    assert product["photoUrl"].endswith(".webp")
    assert any(c["id"] == category.id and c["icon"] == "gift" for c in config["categories"])

    # Фото реально раздаётся
    photo = await admin_client.get(product["photoUrl"].replace("http://test", ""))
    assert photo.status_code == 200

    # Скрыли товар — пропал из приложения, категория без товаров тоже
    await admin_client.post(f"/admin/products/{product['id']}/toggle")
    config = (await admin_client.get("/app/config")).json()
    assert all(p["id"] != product["id"] for p in config["products"])
    assert all(c["id"] != category.id for c in config["categories"])


async def test_product_validation_error_keeps_form(admin_client: AsyncClient):
    category = await _create_category(admin_client, "Ошибки")
    resp = await admin_client.post(
        "/admin/products/new",
        data={"name": f"{P}Без цены", "price": "abc", "category_id": str(category.id)},
    )
    assert resp.status_code == 200
    assert "Укажите цену" in resp.text
    assert f"{P}Без цены" in resp.text


async def test_category_with_products_is_not_deleted(admin_client: AsyncClient):
    category = await _create_category(admin_client, "Занятая")
    await admin_client.post(
        "/admin/products/new",
        data={"name": f"{P}Товар", "price": "100", "category_id": str(category.id), "is_available": "on"},
    )
    resp = await admin_client.post(f"/admin/categories/{category.id}/delete")
    assert "error=notempty" in resp.headers["location"]
    async with async_session_factory() as s:
        assert await s.get(Category, category.id) is not None


# --- настройки → /app/config и расчёт заказа --------------------------------


async def test_settings_drive_app_config_and_order_total(admin_client: AsyncClient):
    resp = await admin_client.post(
        "/admin/settings",
        data={"brandName": "TUR TUK Test", "accentColor": "#123456", "tagline": "t",
              "deliveryPromise": "За 30 минут", "minOrderTotal": "1000", "deliveryFee": "150",
              "freeDeliveryFrom": "2000", "etaMinutes": "30", "cardEnabled": "on",
              "warehouseLat": "36.6", "warehouseLng": "30.56",
              "phone": "+90 555 000 00 00", "privacyPolicyUrl": "https://example.com/privacy",
              "banner_title_0": "Привет", "banner_subtitle_0": "Мир"},
        files={"logo": ("logo.png", _png(), "image/png")},
    )
    assert resp.status_code == 302

    config = (await admin_client.get("/app/config")).json()
    assert config["brand"]["name"] == "TUR TUK Test"
    assert config["brand"]["accentColor"] == "#123456"
    assert config["brand"]["logoUrl"].startswith("http://test/media/brand/")
    assert config["delivery"]["minOrderTotal"] == 1000
    assert config["delivery"]["deliveryFee"] == 150
    assert config["payment"] == {"cardEnabled": True, "sbpEnabled": False, "cashEnabled": False}
    assert config["contacts"]["privacyPolicyUrl"] == "https://example.com/privacy"
    assert config["banners"] == [{"title": "Привет", "subtitle": "Мир"}]

    # Сервер считает заказ по тем же суммам
    category = await _create_category(admin_client, "Для заказа")
    async with async_session_factory() as s:
        product = Product(name=f"{P}Чай", price=1200, category_id=category.id)
        hotel = Hotel(name=f"{P}Отель", is_active=True)
        s.add_all([product, hotel])
        await s.commit()
        await s.refresh(product)
    guest = await _make_user(f"{TEST_PHONE_PREFIX}990010", RoleCode.CLIENT.value)
    order = await admin_client.post(
        "/orders",
        json={"hotel_name": f"{P}Отель", "room_number": "12",
              "items": [{"product_id": product.id, "quantity": 1}], "payment_method": "card"},
        headers={"Authorization": f"Bearer {create_access_token(guest.id)}"},
    )
    assert order.status_code == 201, order.text
    body = order.json()
    assert body["delivery_fee"] == 150
    assert body["total"] == 1350
    assert body["payment_method"] == "card"


async def test_etag_returns_304_when_unchanged(admin_client: AsyncClient):
    first = await admin_client.get("/app/config")
    etag = first.headers["etag"]
    second = await admin_client.get("/app/config", headers={"If-None-Match": etag})
    assert second.status_code == 304


# --- отели --------------------------------------------------------------------


async def test_hotel_toggle_controls_app_list(admin_client: AsyncClient):
    resp = await admin_client.post(
        "/admin/hotels/new",
        data={"name": f"{P}Sea View", "address": "Kemer", "lat": "36,61", "lon": "30.55", "is_active": "on"},
    )
    assert resp.status_code == 302
    config = (await admin_client.get("/app/config")).json()
    hotel = next(h for h in config["hotels"] if h["name"] == f"{P}Sea View")
    assert hotel["lat"] == 36.61  # запятая в координатах принимается

    await admin_client.post(f"/admin/hotels/{hotel['id']}/toggle")
    config = (await admin_client.get("/app/config")).json()
    assert all(h["id"] != hotel["id"] for h in config["hotels"])

    dup = await admin_client.post("/admin/hotels/new", data={"name": f"{P}sea view"})
    assert "error=duplicate" in dup.headers["location"]


async def test_hotel_csv_import_semicolon(admin_client: AsyncClient):
    csv_text = f"name;address;lat;lon\n{P}Csv One;Beldibi;36.7;30.5\n"
    resp = await admin_client.post(
        "/admin/hotels/import", files={"file": ("h.csv", csv_text.encode(), "text/csv")}
    )
    assert resp.status_code == 302
    async with async_session_factory() as s:
        hotel = (await s.execute(select(Hotel).where(Hotel.name == f"{P}Csv One"))).scalar_one()
        assert float(hotel.lat) == 36.7


# --- промокоды ----------------------------------------------------------------


async def test_promo_created_in_admin_validates_in_api(admin_client: AsyncClient):
    resp = await admin_client.post(
        "/admin/promo/new",
        data={"code": "zzadm15", "title": "Тест", "kind": "percent", "value": "15", "is_active": "on"},
    )
    assert resp.status_code == 302
    check = await admin_client.post("/promo/validate", json={"code": "ZZADM15", "cart_total": 1000})
    assert check.status_code == 200
    assert check.json()["discount_amount"] == 150

    bad = await admin_client.post(
        "/admin/promo/new", data={"code": "ZZADMX", "kind": "percent", "value": "150"}
    )
    assert bad.status_code == 200
    assert "больше 100" in bad.text


# --- сотрудники и заказы ------------------------------------------------------


async def test_staff_courier_and_order_assignment(admin_client: AsyncClient):
    resp = await admin_client.post(
        "/admin/staff/new", data={"phone": "+7 000 099-00-20", "name": "Курьер", "role": "courier"}
    )
    assert resp.status_code == 302
    async with async_session_factory() as s:
        courier = (await s.execute(select(User).where(User.phone == f"{TEST_PHONE_PREFIX}990020"))).scalar_one()

    guest = await _make_user(f"{TEST_PHONE_PREFIX}990021", RoleCode.CLIENT.value)
    async with async_session_factory() as s:
        order = Order(user_id=guest.id, total=3000, hotel_name="X", room_number="1")
        s.add(order)
        await s.commit()
        await s.refresh(order)

    page = await admin_client.get(f"/admin/orders/{order.id}")
    assert page.status_code == 200 and f"#{order.id}" in page.text

    await admin_client.post(f"/admin/orders/{order.id}/assign-courier", data={"courier_id": str(courier.id)})
    await admin_client.post(f"/admin/orders/{order.id}/status", data={"status": "accepted"})
    async with async_session_factory() as s:
        fresh = await s.get(Order, order.id)
        assert fresh.courier_id == courier.id
        assert fresh.status == OrderStatus.ACCEPTED
        logs = (await s.execute(select(OrderStatusLog).where(OrderStatusLog.order_id == order.id))).scalars().all()
        assert len(logs) == 1


async def test_admin_password_must_be_long_enough(admin_client: AsyncClient):
    resp = await admin_client.post(
        "/admin/staff/new", data={"phone": "+70000990030", "role": "admin", "password": "123"}
    )
    assert "error=password" in resp.headers["location"]
