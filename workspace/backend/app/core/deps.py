"""FastAPI-зависимости для аутентификации и ролевого доступа (RBAC).

`get_current_user` — единственное место, где access-токен превращается
в загруженного из БД пользователя. `require_role` строится поверх неё, а
не дублирует разбор токена: иначе рано или поздно завелись бы два способа
проверить «кто это» с разным поведением на истёкшем токене.
"""

from collections.abc import Sequence

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.security import InvalidTokenError, decode_token
from app.db.session import get_session
from app.models.user import User

# auto_error=False — иначе FastAPI/Starlette у HTTPBearer отвечает 403 на
# отсутствующий заголовок Authorization, а критерий приёмки требует 401
# (общепринятая семантика: 401 — не авторизован вовсе, 403 — авторизован,
# но роли не хватает). Разбираем credentials сами и различаем эти два случая.
_bearer_scheme = HTTPBearer(auto_error=False)

_UNAUTHORIZED = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="не авторизован: нужен действующий access-токен",
    headers={"WWW-Authenticate": "Bearer"},
)


async def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer_scheme),
    session: AsyncSession = Depends(get_session),
) -> User:
    if credentials is None:
        raise _UNAUTHORIZED

    try:
        payload = decode_token(credentials.credentials, expected_type="access")
    except InvalidTokenError as exc:
        raise _UNAUTHORIZED from exc

    try:
        user_id = int(payload["sub"])
    except (KeyError, TypeError, ValueError) as exc:
        raise _UNAUTHORIZED from exc

    result = await session.execute(
        select(User).options(selectinload(User.role)).where(User.id == user_id)
    )
    user = result.scalar_one_or_none()
    if user is None or not user.is_active:
        # Пользователь удалён или отключён в админке (курьер уволен, гость
        # удалил аккаунт) — выданный ранее токен больше не действует.
        raise _UNAUTHORIZED
    return user


def require_role(roles: Sequence[str]):
    """Фабрика зависимостей: `Depends(require_role(["admin", "owner"]))`.

    Роль вне списка -> 403. Отсутствие/невалидность токена -> 401 (через
    `get_current_user` как под-зависимость) — недостаточно прав и отсутствие
    личности вообще это разные исходы, их нельзя схлопывать в один код.
    """

    allowed = set(roles)

    async def _dependency(user: User = Depends(get_current_user)) -> User:
        if user.role.code not in allowed:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="недостаточно прав для этого действия",
            )
        return user

    return _dependency
