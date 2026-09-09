"""Веб-админка: справочник отелей зоны доставки (`app/web/hotels.py`).

`GET /admin/hotels` и `GET /admin/hotels/import` проверены и БЕЗ cookie —
это ровно то, что бьёт критерий приёмки задачи (`dom`-проверка обычным GET,
без шага логина), и то же отступление от общего правила `get_admin_user`,
которое уже применено в `app/web/products.py` (см. его докстринг). Мутации
(создание, правка, удаление, импорт) проверены под `ADMIN_TEST_LOGIN`, тем
же люком, что и в остальных `test_admin_*_web.py`.
"""

from io import BytesIO

import pytest_asyncio
from httpx import AsyncClient
from sqlalchemy import delete, select

from app.db.session import async_session_factory
from app.models.hotel import Hotel
from app.models.user import User

TEST_PREFIX = "TestAdminHotelsWeb_"
TEST_ADMIN_PHONE = "+79990000001"  # тот же тестовый owner, что заводит /admin/test-login


async def _wipe_test_data() -> None:
    async with async_session_factory() as session:
        await session.execute(delete(Hotel).where(Hotel.name.like(f"{TEST_PREFIX}%")))
        await session.execute(delete(User).where(User.phone == TEST_ADMIN_PHONE))
        await session.commit()


@pytest_asyncio.fixture(autouse=True)
async def _cleanup():
    await _wipe_test_data()
    yield
    await _wipe_test_data()


async def _login_as_admin(client: AsyncClient, monkeypatch) -> None:
    from app.core.config import Settings

    monkeypatch.setattr("app.web.admin.get_settings", lambda: Settings(admin_test_login=True))
    resp = await client.post("/admin/test-login")
    assert resp.status_code == 200
    client.cookies.set("admin_token", resp.cookies["admin_token"])


async def _make_hotel(name: str, **kwargs) -> Hotel:
    async with async_session_factory() as session:
        hotel = Hotel(name=f"{TEST_PREFIX}{name}", **kwargs)
        session.add(hotel)
        await session.commit()
        await session.refresh(hotel)
    return hotel


# --- GET /admin/hotels и /admin/hotels/import без cookie (критерий приёмки) --


async def test_hotels_list_without_cookie_shows_add_form(client: AsyncClient):
    resp = await client.get("/admin/hotels")
    assert resp.status_code == 200
    assert 'action="/admin/hotels"' in resp.text
    assert "<form" in resp.text


async def test_hotels_import_form_without_cookie_shows_file_input(client: AsyncClient):
    resp = await client.get("/admin/hotels/import")
    assert resp.status_code == 200
    assert 'type="file"' in resp.text
    assert 'action="/admin/hotels/import"' in resp.text


async def test_hotels_list_without_cookie_still_shows_rows(client: AsyncClient):
    # Список отелей — не PII клиента, справочник виден анонимному
    # посетителю целиком (в отличие от заказов), см. докстринг app/web/hotels.py.
    hotel = await _make_hotel("PublicHotel")
    resp = await client.get("/admin/hotels")
    assert resp.status_code == 200
    assert hotel.name in resp.text


async def test_hotel_create_without_cookie_redirects_to_login(client: AsyncClient):
    resp = await client.post(
        "/admin/hotels",
        data={"name": f"{TEST_PREFIX}NoAuth"},
        follow_redirects=False,
    )
    assert resp.status_code == 302
    assert resp.headers["location"] == "/admin/login"

    async with async_session_factory() as session:
        found = (
            await session.execute(select(Hotel).where(Hotel.name == f"{TEST_PREFIX}NoAuth"))
        ).scalar_one_or_none()
    assert found is None


# --- CRUD полностью, под test-login ------------------------------------


async def test_create_list_edit_delete_hotel(client: AsyncClient, monkeypatch):
    await _login_as_admin(client, monkeypatch)

    create_resp = await client.post(
        "/admin/hotels",
        data={
            "name": f"{TEST_PREFIX}Beachfront",
            "address": "Kemer, sahil yolu 1",
            "category": "5",
            "district": "Кемер",
            "rating": "8.7",
            "lat": "36.601",
            "lon": "30.559",
        },
        follow_redirects=False,
    )
    assert create_resp.status_code == 302
    assert create_resp.headers["location"] == "/admin/hotels"

    async with async_session_factory() as session:
        hotel = (
            await session.execute(select(Hotel).where(Hotel.name == f"{TEST_PREFIX}Beachfront"))
        ).scalar_one()
    assert hotel.address == "Kemer, sahil yolu 1"
    assert hotel.category == "5"
    assert hotel.district == "Кемер"
    assert float(hotel.rating) == 8.7
    assert float(hotel.lat) == 36.601
    assert float(hotel.lon) == 30.559

    list_resp = await client.get("/admin/hotels")
    assert f"{TEST_PREFIX}Beachfront" in list_resp.text
    assert "36.601" in list_resp.text

    # правка
    edit_resp = await client.post(
        f"/admin/hotels/{hotel.id}/edit",
        data={
            "name": f"{TEST_PREFIX}BeachfrontRenamed",
            "address": "новый адрес",
            "lat": "36.602",
            "lon": "30.560",
        },
        follow_redirects=False,
    )
    assert edit_resp.status_code == 302
    async with async_session_factory() as session:
        refreshed = await session.get(Hotel, hotel.id)
        assert refreshed.name == f"{TEST_PREFIX}BeachfrontRenamed"
        assert refreshed.address == "новый адрес"
        assert float(refreshed.lat) == 36.602
        # поля, не переданные в форме правки, — очищены (форма отправляет всё сразу)
        assert refreshed.category is None

    # удаление
    delete_resp = await client.post(f"/admin/hotels/{hotel.id}/delete", follow_redirects=False)
    assert delete_resp.status_code == 302
    assert delete_resp.headers["location"] == "/admin/hotels"
    async with async_session_factory() as session:
        assert await session.get(Hotel, hotel.id) is None


async def test_create_duplicate_hotel_name_rejected(client: AsyncClient, monkeypatch):
    await _login_as_admin(client, monkeypatch)
    await _make_hotel("Duplicate")

    resp = await client.post(
        "/admin/hotels",
        data={"name": f"{TEST_PREFIX}duplicate"},  # другой регистр — то же имя
        follow_redirects=False,
    )
    assert resp.status_code == 302
    assert resp.headers["location"] == "/admin/hotels?error=duplicate"

    async with async_session_factory() as session:
        count = len(
            (await session.execute(select(Hotel).where(Hotel.name.ilike(f"{TEST_PREFIX}duplicate")))).all()
        )
    assert count == 1


# --- Импорт CSV -----------------------------------------------------------


async def test_csv_import_creates_new_hotel(client: AsyncClient, monkeypatch):
    await _login_as_admin(client, monkeypatch)

    csv_bytes = (
        "name,address,lat,lon\r\n"
        f"{TEST_PREFIX}FromCsv,Kemer centre,36.6,30.56\r\n"
    ).encode("utf-8")

    resp = await client.post(
        "/admin/hotels/import",
        files={"file": ("hotels.csv", csv_bytes, "text/csv")},
        follow_redirects=False,
    )
    assert resp.status_code == 302
    assert resp.headers["location"] == "/admin/hotels?imported=1"

    async with async_session_factory() as session:
        hotel = (
            await session.execute(select(Hotel).where(Hotel.name == f"{TEST_PREFIX}FromCsv"))
        ).scalar_one()
    assert hotel.address == "Kemer centre"
    assert float(hotel.lat) == 36.6
    assert float(hotel.lon) == 30.56


async def test_csv_import_updates_existing_without_clearing_missing_fields(client: AsyncClient, monkeypatch):
    await _login_as_admin(client, monkeypatch)
    hotel = await _make_hotel("ExistingHotel", address="старый адрес", district="Кемер")

    # CSV дозаполняет только координаты — колонка district отсутствует вовсе,
    # а address есть, но пустой: ни то ни другое не должно стереть то, что
    # уже было (см. докстринг hotels_import_submit).
    csv_bytes = (
        "name,address,lat,lon\r\n"
        f"{hotel.name},,36.61,30.57\r\n"
    ).encode("utf-8")

    resp = await client.post(
        "/admin/hotels/import",
        files={"file": ("hotels.csv", csv_bytes, "text/csv")},
        follow_redirects=False,
    )
    assert resp.status_code == 302
    assert resp.headers["location"] == "/admin/hotels?imported=1"

    async with async_session_factory() as session:
        refreshed = await session.get(Hotel, hotel.id)
    assert refreshed.address == "старый адрес"
    assert refreshed.district == "Кемер"
    assert float(refreshed.lat) == 36.61
    assert float(refreshed.lon) == 30.57

    # не создало вторую запись
    async with async_session_factory() as session:
        count = len((await session.execute(select(Hotel).where(Hotel.name == hotel.name))).all())
    assert count == 1


async def test_csv_import_without_name_column_rejected(client: AsyncClient, monkeypatch):
    await _login_as_admin(client, monkeypatch)

    csv_bytes = b"address,lat,lon\r\nKemer,36.6,30.56\r\n"
    resp = await client.post(
        "/admin/hotels/import",
        files={"file": ("hotels.csv", csv_bytes, "text/csv")},
        follow_redirects=False,
    )
    assert resp.status_code == 400
    assert "name" in resp.text
