"""FCM HTTP v1 без сети: подменяем HTTP-транспорт httpx и проверяем, что
уходит в Google — подписанный JWT, формат сообщения, кэш OAuth-токена и
стирание недействительного токена устройства.
"""

import json

import httpx
import jwt
import pytest_asyncio
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from sqlalchemy import select

from app.core.fcm import FcmSender, load_service_account
from app.db.session import async_session_factory
from app.models.role import Role, RoleCode
from app.models.user import User
from tests.conftest import TEST_PHONE_PREFIX, cleanup_test_users

PHONE = f"{TEST_PHONE_PREFIX}880001"


def _service_account() -> tuple[dict, rsa.RSAPrivateKey]:
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    pem = key.private_bytes(
        serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()
    ).decode()
    return {"project_id": "turtuk-test", "client_email": "push@turtuk-test.iam.gserviceaccount.com",
            "private_key": pem}, key


class FakeGoogle:
    def __init__(self, send_status: int = 200, send_body: str = "{}") -> None:
        self.calls: list[httpx.Request] = []
        self.send_status = send_status
        self.send_body = send_body

    def __call__(self, request: httpx.Request) -> httpx.Response:
        self.calls.append(request)
        if request.url.host == "oauth2.googleapis.com":
            return httpx.Response(200, json={"access_token": "ya29.test", "expires_in": 3600})
        return httpx.Response(self.send_status, text=self.send_body)


@pytest_asyncio.fixture
async def user_with_token():
    await cleanup_test_users(f"{TEST_PHONE_PREFIX}88")
    async with async_session_factory() as s:
        role = (await s.execute(select(Role).where(Role.code == RoleCode.CLIENT.value))).scalar_one()
        user = User(phone=PHONE, role_id=role.id, fcm_token="device-token-123")
        s.add(user)
        await s.commit()
        await s.refresh(user)
    yield user
    await cleanup_test_users(f"{TEST_PHONE_PREFIX}88")


async def test_sends_v1_message_with_signed_oauth(user_with_token):
    sa, key = _service_account()
    google = FakeGoogle()
    sender = FcmSender(sa, http=httpx.AsyncClient(transport=httpx.MockTransport(google)))

    await sender.send(user_with_token.id, "Заказ №5 принят", "Собираем")
    await sender.send(user_with_token.id, "Заказ №5 в пути", "Курьер едет")

    oauth = [c for c in google.calls if c.url.host == "oauth2.googleapis.com"]
    sends = [c for c in google.calls if c.url.host == "fcm.googleapis.com"]
    assert len(oauth) == 1, "OAuth-токен кэшируется между отправками"
    assert len(sends) == 2

    assertion = dict(x.split("=", 1) for x in oauth[0].content.decode().split("&"))["assertion"]
    claims = jwt.decode(assertion, key.public_key(), algorithms=["RS256"],
                        audience="https://oauth2.googleapis.com/token")
    assert claims["iss"] == sa["client_email"]

    assert sends[0].url.path == "/v1/projects/turtuk-test/messages:send"
    assert sends[0].headers["authorization"] == "Bearer ya29.test"
    message = json.loads(sends[0].content)["message"]
    assert message["token"] == "device-token-123"
    assert message["notification"] == {"title": "Заказ №5 принят", "body": "Собираем"}


async def test_unregistered_token_is_forgotten(user_with_token):
    sa, _ = _service_account()
    google = FakeGoogle(404, '{"error":{"status":"NOT_FOUND","details":[{"errorCode":"UNREGISTERED"}]}}')
    sender = FcmSender(sa, http=httpx.AsyncClient(transport=httpx.MockTransport(google)))

    await sender.send(user_with_token.id, "t", "b")

    async with async_session_factory() as s:
        assert (await s.get(User, user_with_token.id)).fcm_token is None


async def test_no_device_token_means_no_request(user_with_token):
    async with async_session_factory() as s:
        (await s.get(User, user_with_token.id)).fcm_token = None
        await s.commit()
    sa, _ = _service_account()
    google = FakeGoogle()
    sender = FcmSender(sa, http=httpx.AsyncClient(transport=httpx.MockTransport(google)))
    await sender.send(user_with_token.id, "t", "b")
    assert google.calls == []


def test_service_account_from_json_string():
    sa, _ = _service_account()
    assert load_service_account(json.dumps(sa))["project_id"] == "turtuk-test"
