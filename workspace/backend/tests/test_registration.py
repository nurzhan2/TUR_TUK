"""Регистрация клиента: POST /auth/register.

Довносит name/dob/hotel_name/room_number пользователю, заведённому на шаге
верификации телефона (test_auth.py). Реальный Postgres, тот же контур, что
у остальных файлов — свой префикс телефона (+70003) и свой префикс имён
отелей для очистки.
"""

from datetime import date, timedelta

import pytest_asyncio
from httpx import AsyncClient
from sqlalchemy import delete, select

from app.core.security import create_access_token
from app.db.session import async_session_factory
from app.models.hotel import Hotel
from app.models.role import Role, RoleCode
from app.models.user import User

TEST_PHONE_PREFIX = "+70003"
TEST_HOTEL_PREFIX = "TestReg_"


async def _wipe_registration_test_data() -> None:
    async with async_session_factory() as session:
        await session.execute(delete(User).where(User.phone.like(f"{TEST_PHONE_PREFIX}%")))
        await session.execute(delete(Hotel).where(Hotel.name.like(f"{TEST_HOTEL_PREFIX}%")))
        await session.commit()


@pytest_asyncio.fixture(autouse=True)
async def _cleanup_registration_data():
    await _wipe_registration_test_data()
    yield
    await _wipe_registration_test_data()


async def _make_user(suffix: str) -> tuple[User, str]:
    async with async_session_factory() as session:
        result = await session.execute(select(Role).where(Role.code == RoleCode.CLIENT.value))
        role = result.scalar_one()
        user = User(phone=f"{TEST_PHONE_PREFIX}{suffix}", role_id=role.id)
        session.add(user)
        await session.commit()
        await session.refresh(user)
    return user, create_access_token(user.id)


async def _make_hotel(name: str) -> Hotel:
    async with async_session_factory() as session:
        hotel = Hotel(name=f"{TEST_HOTEL_PREFIX}{name}")
        session.add(hotel)
        await session.commit()
        await session.refresh(hotel)
    return hotel


def _auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


async def test_register_without_token_is_401(client: AsyncClient):
    resp = await client.post(
        "/auth/register",
        json={
            "name": "Анастасия",
            "dob": "1990-01-01",
            "hotel_name": "Whatever",
            "room_number": "101",
        },
    )
    assert resp.status_code == 401


async def test_register_saves_all_fields(client: AsyncClient):
    _, token = await _make_user("01")
    hotel = await _make_hotel("Rixos01")

    resp = await client.post(
        "/auth/register",
        json={
            "name": "Анастасия",
            "dob": "1990-05-20",
            "hotel_name": hotel.name,
            "room_number": "305",
        },
        headers=_auth(token),
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["name"] == "Анастасия"
    assert body["dob"] == "1990-05-20"
    assert body["hotel_name"] == hotel.name
    assert body["room_number"] == "305"


async def test_register_hotel_name_is_case_insensitive(client: AsyncClient):
    _, token = await _make_user("02")
    hotel = await _make_hotel("Rixos02")

    resp = await client.post(
        "/auth/register",
        json={
            "name": "Иван",
            "dob": "1985-03-15",
            "hotel_name": hotel.name.upper(),
            "room_number": "12",
        },
        headers=_auth(token),
    )
    assert resp.status_code == 200
    assert resp.json()["hotel_name"] == hotel.name


async def test_register_unknown_hotel_is_422(client: AsyncClient):
    _, token = await _make_user("03")

    resp = await client.post(
        "/auth/register",
        json={
            "name": "Пётр",
            "dob": "1992-07-01",
            "hotel_name": f"{TEST_HOTEL_PREFIX}NoSuchHotel",
            "room_number": "7",
        },
        headers=_auth(token),
    )
    assert resp.status_code == 422


async def test_register_future_dob_is_422(client: AsyncClient):
    _, token = await _make_user("04")
    hotel = await _make_hotel("Rixos04")
    future_dob = (date.today() + timedelta(days=1)).isoformat()

    resp = await client.post(
        "/auth/register",
        json={
            "name": "Мария",
            "dob": future_dob,
            "hotel_name": hotel.name,
            "room_number": "9",
        },
        headers=_auth(token),
    )
    assert resp.status_code == 422


async def test_register_missing_fields_is_422(client: AsyncClient):
    _, token = await _make_user("05")

    resp = await client.post("/auth/register", json={"name": "Только имя"}, headers=_auth(token))
    assert resp.status_code == 422


async def test_register_persists_to_db(client: AsyncClient):
    user, token = await _make_user("06")
    hotel = await _make_hotel("Rixos06")

    resp = await client.post(
        "/auth/register",
        json={
            "name": "Ольга",
            "dob": "1988-11-11",
            "hotel_name": hotel.name,
            "room_number": "42",
        },
        headers=_auth(token),
    )
    assert resp.status_code == 200

    async with async_session_factory() as session:
        stored = await session.get(User, user.id)
        assert stored.name == "Ольга"
        assert stored.dob.isoformat() == "1988-11-11"
        assert stored.hotel_name == hotel.name
        assert stored.room_number == "42"
