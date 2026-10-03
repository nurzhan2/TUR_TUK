from datetime import datetime, timedelta, timezone
from typing import Any, Literal

import jwt

from app.core.config import get_settings

TokenType = Literal["access", "refresh"]


class InvalidTokenError(ValueError):
    """Токен не прошёл проверку подписи/срока/типа."""


def _create_token(subject: str, token_type: TokenType, expires_delta: timedelta) -> str:
    settings = get_settings()
    now = datetime.now(timezone.utc)
    payload: dict[str, Any] = {
        "sub": subject,
        "type": token_type,
        "iat": now,
        "exp": now + expires_delta,
    }
    return jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


def create_access_token(user_id: int, *, expires_minutes: int | None = None) -> str:
    settings = get_settings()
    minutes = expires_minutes or settings.jwt_access_token_expire_minutes
    return _create_token(str(user_id), "access", timedelta(minutes=minutes))


def create_refresh_token(user_id: int) -> str:
    settings = get_settings()
    return _create_token(
        str(user_id), "refresh", timedelta(days=settings.jwt_refresh_token_expire_days)
    )


def decode_token(token: str, *, expected_type: TokenType | None = None) -> dict[str, Any]:
    settings = get_settings()
    try:
        payload = jwt.decode(token, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm])
    except jwt.PyJWTError as exc:
        raise InvalidTokenError(str(exc)) from exc

    if expected_type is not None and payload.get("type") != expected_type:
        raise InvalidTokenError(f"ожидался токен типа {expected_type!r}, получен {payload.get('type')!r}")

    return payload
