"""Cookie-аутентификация веб-админки.

Страницы `/admin/*` открывает браузер, поэтому токен живёт в httpOnly-cookie
`admin_token`, а не в заголовке. Без валидной cookie любая страница ведёт
на форму входа (`AdminAuthRequired` ловит `app.main`).

Все страницы админки закрыты — открытых «для проверки разметки» больше нет:
в них были товары, отели и список заказов с телефонами гостей.
"""

from fastapi import Depends, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.rbac import ADMIN_ROLES
from app.core.security import InvalidTokenError, decode_token
from app.db.session import get_session
from app.models.user import User

ADMIN_COOKIE_NAME = "admin_token"


class AdminAuthRequired(Exception):
    """Нет валидного cookie-токена персонала — веди на /admin/login."""


async def get_admin_user(
    request: Request,
    session: AsyncSession = Depends(get_session),
) -> User:
    token = request.cookies.get(ADMIN_COOKIE_NAME)
    if token is None:
        raise AdminAuthRequired()

    try:
        payload = decode_token(token, expected_type="access")
        user_id = int(payload["sub"])
    except (InvalidTokenError, KeyError, TypeError, ValueError) as exc:
        raise AdminAuthRequired() from exc

    result = await session.execute(
        select(User).options(selectinload(User.role)).where(User.id == user_id)
    )
    user = result.scalar_one_or_none()
    if user is None or not user.is_active or user.role.code not in ADMIN_ROLES:
        raise AdminAuthRequired()
    return user


def no_store(response):
    """Страницы админки зависят от cookie, а не от URL — никакого кэша."""
    response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, private"
    response.headers["Pragma"] = "no-cache"
    return response
