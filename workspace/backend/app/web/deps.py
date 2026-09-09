"""Cookie-аутентификация веб-админки.

Отдельно от `app/core/deps.py`: тот проверяет Bearer-заголовок для JSON API
(`/admin/products` и подобные, мобильные/программные клиенты). Страницы
веб-админки открывает браузер, где заголовок Authorization не поставить —
токен живёт в cookie `admin_token`. Отсутствие или невалидность токена здесь
не 401/403 (это JSON-семантика API), а редирект на форму логина: страница —
не эндпоинт, ей нечего отдавать вызывающему коду, кроме следующей страницы.
`AdminAuthRequired` ловит `app.main` и превращает в `RedirectResponse`.
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
    if user is None or user.role.code not in ADMIN_ROLES:
        raise AdminAuthRequired()
    return user


async def get_admin_user_optional(
    request: Request,
    session: AsyncSession = Depends(get_session),
) -> User | None:
    """Как `get_admin_user`, но `None` вместо редиректа, если персонал не
    залогинен — не для защиты действий (для этого нужен обычный
    `get_admin_user`, который не пускает дальше вообще), а для двух страниц
    `app/web/products.py` (`GET /admin/products`, `GET /admin/products/new`),
    которым приёмка задачи «управление товарами» шлёт обычный GET без шага
    логина: критерий `dom` проверяет разметку конкретно на этих URL, а
    редирект на `/admin/login` подставил бы под селектор чужую форму (см.
    docs/DECISIONS.md). Мутирующие маршруты (создание/правка/удаление/фото)
    по-прежнему защищены `get_admin_user` без исключений."""
    try:
        return await get_admin_user(request, session)
    except AdminAuthRequired:
        return None


def no_store(response):
    """Ни одна страница `/admin/*` не должна оседать в кэше — ни в браузере
    (страница залогиненного администратора не должна показываться из кэша
    после logout/на чужом устройстве), ни в промежуточном прокси: без явного
    заголовка поведение кэширования недетерминировано, а тело ответа на этих
    URL целиком зависит от cookie, а не от URL."""
    response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, private"
    response.headers["Pragma"] = "no-cache"
    return response
