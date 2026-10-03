import os
from collections.abc import AsyncIterator

# Должно стоять ДО первого импорта чего-либо из `app.*` (см. ниже) и до любого
# обращения к `get_settings()`: движок в `app/db/session.py` собирается один
# раз на модульном уровне при импорте, `lru_cache` на `get_settings()` фиксирует
# значение намертво на весь процесс pytest.
#
# Посторонний процесс на этой машине (общий девелоперский хост с другими
# проектами) периодически прописывает `DATABASE_URL` в пользовательский
# реестр Windows (см. `docs/DECISIONS.md`, инцидент повторялся минимум
# четыре раза) — указывает на чужой Postgres на порту 5432 без миграций
# этого проекта. `pydantic-settings` по дизайну отдаёт приоритет переменной
# окружения над `.env`/дефолтом в `Settings`, и это осознанное решение для
# продакшна (там секреты и реальный адрес БД задаются именно через
# окружение) — менять эту логику ради теста нельзя. Но тестовый прогон
# обязан быть детерминированным независимо от чужого мусора в окружении
# машины, поэтому здесь, и только здесь, значение фиксируется явно на тот
# же docker-compose-инстанс, что документирован в `.env.example`.
os.environ["DATABASE_URL"] = os.environ.get(
    "TEST_DATABASE_URL", "postgresql+asyncpg://tur_tuk:tur_tuk@localhost:5433/tur_tuk"
)
os.environ.setdefault("MEDIA_DIR", os.path.join(os.path.dirname(__file__), ".media"))
# Все тесты шлют коды с одного адреса — лимит на IP проверяется отдельно,
# а здесь он помешал бы остальным сценариям входа.
os.environ.setdefault("SMS_MAX_PER_IP_HOUR", "100000")

import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy import delete, text

from app.core.sms import SmsProvider
from app.db.session import async_session_factory
from app.main import app
from app.models.sms_code import SmsVerificationCode
from app.models.user import User

# Тестовые номера отличаются от любого реального формата этим префиксом —
# по нему чистим за собой строки в общей (реальной, не mock) БД после теста.
TEST_PHONE_PREFIX = "+70000"


class FakeSmsProvider(SmsProvider):
    """Мок SMS-провайдера — не ходит в сеть, запоминает отправленные коды."""

    def __init__(self) -> None:
        self.sent: dict[str, str] = {}

    async def send(self, phone: str, code: str) -> None:
        self.sent[phone] = code


@pytest_asyncio.fixture
async def fake_sms() -> FakeSmsProvider:
    return FakeSmsProvider()


@pytest_asyncio.fixture
async def client(fake_sms: FakeSmsProvider) -> AsyncIterator[AsyncClient]:
    from app.api.auth import _sms_provider_dependency

    app.dependency_overrides[_sms_provider_dependency] = lambda: fake_sms
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
    app.dependency_overrides.pop(_sms_provider_dependency, None)


@pytest_asyncio.fixture(autouse=True)
async def _cleanup_test_phones() -> AsyncIterator[None]:
    yield
    await cleanup_test_users()


# Таблицы, ссылающиеся на users/orders, — читаются из схемы один раз, чтобы
# уборка не ломалась от новой таблицы с внешним ключом.
_FK_CACHE: dict[str, list[tuple[str, str]]] = {}

_FK_SQL = text(
    """
    select tc.table_name, kcu.column_name
    from information_schema.table_constraints tc
    join information_schema.key_column_usage kcu
      on tc.constraint_name = kcu.constraint_name and tc.table_schema = kcu.table_schema
    join information_schema.constraint_column_usage ccu
      on tc.constraint_name = ccu.constraint_name and tc.table_schema = ccu.table_schema
    where tc.constraint_type = 'FOREIGN KEY' and ccu.table_name = :target
    """
)


async def _refs(session, target: str) -> list[tuple[str, str]]:
    if target not in _FK_CACHE:
        rows = (await session.execute(_FK_SQL, {"target": target})).all()
        _FK_CACHE[target] = [(t, c) for t, c in rows if t != target]
    return _FK_CACHE[target]


async def cleanup_test_users(prefix: str = TEST_PHONE_PREFIX) -> None:
    """Удаляет тестовых пользователей вместе со всем, что на них ссылается:
    заказы (и их позиции, платежи, историю), корзины, сообщения, трек."""
    users = f"(select id from users where phone like '{prefix}%')"
    orders = f"(select id from orders where user_id in {users} or courier_id in {users})"
    async with async_session_factory() as session:
        for table, column in await _refs(session, "orders"):
            await session.execute(text(f"delete from {table} where {column} in {orders}"))
        await session.execute(text(f"delete from orders where id in {orders}"))
        for table, column in await _refs(session, "users"):
            if table == "orders":
                continue
            await session.execute(text(f"delete from {table} where {column} in {users}"))
        await session.execute(
            delete(SmsVerificationCode).where(SmsVerificationCode.phone.like(f"{prefix}%"))
        )
        await session.execute(delete(User).where(User.phone.like(f"{prefix}%")))
        await session.commit()
