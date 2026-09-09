"""Код из SMS → пользователь.

Общее место для JSON-логина (`/auth/verify-code`) и cookie-логина веб-админки
(`/admin/login`) — обе точки входа обязаны принимать код по одним и тем же
правилам, иначе однажды они разойдутся (например, один научится продлевать
TTL, а другой нет) и это всплывёт только на проде.
"""

from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.role import Role, RoleCode
from app.models.sms_code import SmsVerificationCode
from app.models.user import User


class InvalidSmsCode(ValueError):
    """Код не найден по этому номеру, не совпал или истёк."""


async def verify_sms_code(session: AsyncSession, phone: str, code: str) -> User:
    """Гасит код и возвращает пользователя (заводит нового с ролью client,
    если это первый вход). `user.role` гарантированно загружен."""
    now = datetime.now(timezone.utc)

    result = await session.execute(
        select(SmsVerificationCode)
        .where(
            SmsVerificationCode.phone == phone,
            SmsVerificationCode.consumed_at.is_(None),
        )
        .order_by(SmsVerificationCode.id.desc())
        .limit(1)
    )
    record = result.scalar_one_or_none()

    if record is None or record.code != code or record.expires_at < now:
        raise InvalidSmsCode("неверный или истёкший код")

    record.consumed_at = now

    result = await session.execute(
        select(User).options(selectinload(User.role)).where(User.phone == phone)
    )
    user = result.scalar_one_or_none()
    if user is None:
        result = await session.execute(select(Role).where(Role.code == RoleCode.CLIENT.value))
        client_role = result.scalar_one()
        user = User(phone=phone, role_id=client_role.id)
        user.role = client_role
        session.add(user)
        await session.flush()

    return user
