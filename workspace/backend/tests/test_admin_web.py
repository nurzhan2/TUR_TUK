"""Веб-админка: cookie-логин и защита /admin/*.

Отдельно от tests/test_rbac.py, который проверяет JSON-эндпоинты
`app/api/admin.py` под Bearer-токеном — здесь проверяются HTML-страницы
`app/web/admin.py` под cookie-токеном.
"""

import pytest_asyncio
from sqlalchemy import delete, select

from app.models.role import Role, RoleCode
from app.models.sms_code import SmsVerificationCode
from app.models.user import User

TEST_PHONE_PREFIX = "+70002"
ADMIN_ROLES = [RoleCode.ADMIN.value, RoleCode.OWNER.value, RoleCode.DIRECTOR.value]


def _phone(suffix: str) -> str:
    return f"{TEST_PHONE_PREFIX}{suffix}"


@pytest_asyncio.fixture(autouse=True)
async def _cleanup_admin_web_data():
    async def _wipe():
        from app.db.session import async_session_factory

        async with async_session_factory() as session:
            await session.execute(
                delete(SmsVerificationCode).where(SmsVerificationCode.phone.like(f"{TEST_PHONE_PREFIX}%"))
            )
            await session.execute(delete(User).where(User.phone.like(f"{TEST_PHONE_PREFIX}%")))
            await session.commit()

    await _wipe()
    yield
    await _wipe()


async def _make_user(role_code: str, suffix: str) -> User:
    from app.db.session import async_session_factory

    async with async_session_factory() as session:
        result = await session.execute(select(Role).where(Role.code == role_code))
        role = result.scalar_one()
        user = User(phone=_phone(suffix), role_id=role.id)
        session.add(user)
        await session.commit()
        await session.refresh(user)
    return user


async def _send_and_get_code(client, fake_sms, phone: str) -> str:
    await client.post("/auth/send-code", json={"phone": phone})
    return fake_sms.sent[phone]


async def test_dashboard_without_cookie_redirects_to_login(client):
    resp = await client.get("/admin/", follow_redirects=False)
    assert resp.status_code == 302
    assert resp.headers["location"] == "/admin/login"


async def test_login_form_renders(client):
    resp = await client.get("/admin/login")
    assert resp.status_code == 200
    assert "<form" in resp.text


async def test_login_wrong_code_is_400(client):
    user = await _make_user(RoleCode.OWNER.value, "001")
    resp = await client.post(
        "/admin/login",
        data={"phone": user.phone, "code": "0000"},
        follow_redirects=False,
    )
    assert resp.status_code == 400
    assert "admin_token" not in resp.cookies


async def test_login_non_admin_role_is_403(client, fake_sms):
    user = await _make_user(RoleCode.CLIENT.value, "002")
    code = await _send_and_get_code(client, fake_sms, user.phone)

    resp = await client.post(
        "/admin/login",
        data={"phone": user.phone, "code": code},
        follow_redirects=False,
    )
    assert resp.status_code == 403
    assert "admin_token" not in resp.cookies


async def test_login_admin_role_sets_cookie_and_redirects(client, fake_sms):
    user = await _make_user(RoleCode.OWNER.value, "003")
    code = await _send_and_get_code(client, fake_sms, user.phone)

    resp = await client.post(
        "/admin/login",
        data={"phone": user.phone, "code": code},
        follow_redirects=False,
    )
    assert resp.status_code == 302
    assert resp.headers["location"] == "/admin/"
    assert "admin_token" in resp.cookies

    client.cookies.set("admin_token", resp.cookies["admin_token"])
    dashboard = await client.get("/admin/")
    assert dashboard.status_code == 200
    assert "<nav" in dashboard.text


async def test_test_login_disabled_by_default_is_404(client):
    resp = await client.post("/admin/test-login")
    assert resp.status_code == 404


async def test_test_login_enabled_opens_dashboard(client, monkeypatch):
    from app.core.config import Settings

    monkeypatch.setattr(
        "app.web.admin.get_settings",
        lambda: Settings(admin_test_login=True),
    )

    resp = await client.post("/admin/test-login")
    assert resp.status_code == 200
    assert "admin_token" in resp.cookies

    client.cookies.set("admin_token", resp.cookies["admin_token"])
    dashboard = await client.get("/admin/")
    assert dashboard.status_code == 200
    assert "<nav" in dashboard.text

    # уборка за собой: test-login заводит фиксированного тестового owner'а
    from app.db.session import async_session_factory

    async with async_session_factory() as session:
        await session.execute(delete(User).where(User.phone == "+79990000001"))
        await session.commit()
