"""Отправка push через Firebase Cloud Messaging HTTP v1.

Legacy-API (`fcm.googleapis.com/fcm/send` с `key=<server key>`) Google
отключил в 2024 году — на нём ни одно уведомление не дошло бы. HTTP v1:

1. JWT сервисного аккаунта (RS256, ключ из JSON Firebase) меняется на
   OAuth2 access token в `oauth2.googleapis.com/token`; токен живёт час,
   держим его в памяти и обновляем за 5 минут до истечения.
2. `POST /v1/projects/{project_id}/messages:send` с этим токеном.

Без google-auth SDK: подпись делает уже установленный PyJWT (+cryptography),
HTTP — httpx, как у SMS-провайдеров. `send(user_id, ...)` сам находит токен
устройства; токен, который FCM назвал недействительным (приложение удалено,
переустановлено), стирается — иначе каждый заказ слал бы push в пустоту.
"""

from __future__ import annotations

import json
import time
from pathlib import Path

import httpx
import jwt

from app.core.notifications import NotificationSendError, NotificationSender
from app.db.session import async_session_factory
from app.models.user import User

_TOKEN_URL = "https://oauth2.googleapis.com/token"
_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
_SEND_URL = "https://fcm.googleapis.com/v1/projects/{project}/messages:send"


def _is_dead_token(resp: httpx.Response) -> bool:
    """FCM говорит «такого устройства больше нет»: 404 UNREGISTERED или 400
    INVALID_ARGUMENT про registration token. Остальные ошибки — наши."""
    text = resp.text
    if resp.status_code == 404 and "UNREGISTERED" in text:
        return True
    return resp.status_code == 400 and "registration token" in text.lower()


def load_service_account(raw: str) -> dict:
    """Путь к JSON-файлу ключа или сам JSON строкой (удобно для секретов в env)."""
    text = raw.strip()
    if not text.startswith("{"):
        text = Path(text).read_text(encoding="utf-8")
    data = json.loads(text)
    for field in ("project_id", "client_email", "private_key"):
        if not data.get(field):
            raise NotificationSendError(f"FCM: в ключе сервисного аккаунта нет поля {field}")
    return data


class FcmSender(NotificationSender):
    def __init__(self, service_account: dict, *, http: httpx.AsyncClient | None = None) -> None:
        self._sa = service_account
        self._http = http
        self._token: str | None = None
        self._token_expires = 0.0

    async def _client(self) -> httpx.AsyncClient:
        if self._http is None:
            self._http = httpx.AsyncClient(timeout=10)
        return self._http

    async def _access_token(self) -> str:
        if self._token and time.time() < self._token_expires - 300:
            return self._token
        now = int(time.time())
        assertion = jwt.encode(
            {
                "iss": self._sa["client_email"],
                "scope": _SCOPE,
                "aud": _TOKEN_URL,
                "iat": now,
                "exp": now + 3600,
            },
            self._sa["private_key"],
            algorithm="RS256",
        )
        client = await self._client()
        resp = await client.post(
            _TOKEN_URL,
            data={"grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion": assertion},
        )
        if resp.status_code != 200:
            raise NotificationSendError(f"fcm oauth: {resp.status_code} {resp.text[:200]}")
        body = resp.json()
        self._token = body["access_token"]
        self._token_expires = time.time() + int(body.get("expires_in", 3600))
        return self._token

    async def send(self, user_id: int, title: str, body: str, data: dict | None = None) -> None:
        token = await self._device_token(user_id)
        if token is None:
            # Устройство не зарегистрировано (не вошёл в приложение или запретил
            # уведомления) — слать некуда, это не ошибка провайдера.
            return

        message: dict = {
            "token": token,
            "notification": {"title": title, "body": body},
            "android": {"priority": "high", "notification": {"sound": "default"}},
            "apns": {"payload": {"aps": {"sound": "default"}}},
        }
        if data:
            message["data"] = {k: str(v) for k, v in data.items()}

        client = await self._client()
        resp = await client.post(
            _SEND_URL.format(project=self._sa["project_id"]),
            headers={"Authorization": f"Bearer {await self._access_token()}"},
            json={"message": message},
        )
        if resp.status_code == 200:
            return
        if _is_dead_token(resp):
            await self._forget_token(user_id, token)
            return
        raise NotificationSendError(f"fcm: {resp.status_code} {resp.text[:300]}")

    async def _device_token(self, user_id: int) -> str | None:
        async with async_session_factory() as session:
            user = await session.get(User, user_id)
            return user.fcm_token if user is not None else None

    async def _forget_token(self, user_id: int, token: str) -> None:
        async with async_session_factory() as session:
            user = await session.get(User, user_id)
            if user is not None and user.fcm_token == token:
                user.fcm_token = None
                await session.commit()
