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
os.environ["DATABASE_URL"] = "postgresql+asyncpg://tur_tuk:tur_tuk@localhost:5433/tur_tuk"

import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy import delete

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
    async with async_session_factory() as session:
        await session.execute(
            delete(SmsVerificationCode).where(SmsVerificationCode.phone.like(f"{TEST_PHONE_PREFIX}%"))
        )
        await session.execute(delete(User).where(User.phone.like(f"{TEST_PHONE_PREFIX}%")))
        await session.commit()
