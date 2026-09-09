"""POST /promo/validate: скидка по промокоду, три обязательных сценария отказа —
истёкший код, превышение лимита использований, несуществующий код.

Реальный Postgres, тот же контур, что у остальных тестов — свой префикс
`TestPromo_` в коде промокода, autouse-очистка до и после.
"""

from datetime import datetime, timedelta, timezone

import pytest_asyncio
from httpx import AsyncClient
from sqlalchemy import delete

from app.db.session import async_session_factory
from app.models.promo_code import PromoCode

TEST_PREFIX = "TestPromo_"


async def _wipe_promo_test_data() -> None:
    async with async_session_factory() as session:
        await session.execute(delete(PromoCode).where(PromoCode.code.like(f"{TEST_PREFIX}%")))
        await session.commit()


@pytest_asyncio.fixture(autouse=True)
async def _cleanup_promo_data():
    await _wipe_promo_test_data()
    yield
    await _wipe_promo_test_data()


async def _make_promo(
    suffix: str,
    *,
    discount_percent: float | None = None,
    discount_amount: float | None = None,
    is_active: bool = True,
    valid_until: datetime | None = None,
    max_uses: int | None = None,
    used_count: int = 0,
) -> PromoCode:
    async with async_session_factory() as session:
        promo = PromoCode(
            code=f"{TEST_PREFIX}{suffix}",
            discount_percent=discount_percent,
            discount_amount=discount_amount,
            is_active=is_active,
            valid_until=valid_until,
            max_uses=max_uses,
            used_count=used_count,
        )
        session.add(promo)
        await session.commit()
        await session.refresh(promo)
    return promo


async def test_percent_discount_applied(client: AsyncClient):
    promo = await _make_promo("PCT10", discount_percent=10)

    resp = await client.post(
        "/promo/validate", json={"code": promo.code, "cart_total": 1000}
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["discount_amount"] == 100
    assert body["total_after_discount"] == 900


async def test_fixed_discount_applied(client: AsyncClient):
    promo = await _make_promo("FIX200", discount_amount=200)

    resp = await client.post(
        "/promo/validate", json={"code": promo.code, "cart_total": 1000}
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["discount_amount"] == 200
    assert body["total_after_discount"] == 800


async def test_fixed_discount_capped_at_cart_total(client: AsyncClient):
    promo = await _make_promo("BIGFIX", discount_amount=5000)

    resp = await client.post(
        "/promo/validate", json={"code": promo.code, "cart_total": 1000}
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["discount_amount"] == 1000
    assert body["total_after_discount"] == 0


async def test_code_lookup_is_case_insensitive(client: AsyncClient):
    promo = await _make_promo("caseTest", discount_percent=5)

    resp = await client.post(
        "/promo/validate", json={"code": promo.code.upper(), "cart_total": 1000}
    )
    assert resp.status_code == 200


async def test_unknown_promo_code_is_404(client: AsyncClient):
    resp = await client.post(
        "/promo/validate", json={"code": f"{TEST_PREFIX}DOES_NOT_EXIST", "cart_total": 1000}
    )
    assert resp.status_code == 404


async def test_expired_promo_rejected(client: AsyncClient):
    promo = await _make_promo(
        "EXPIRED",
        discount_percent=10,
        valid_until=datetime.now(timezone.utc) - timedelta(days=1),
    )

    resp = await client.post(
        "/promo/validate", json={"code": promo.code, "cart_total": 1000}
    )
    assert resp.status_code == 422


async def test_promo_not_yet_expired_is_accepted(client: AsyncClient):
    promo = await _make_promo(
        "NOTEXPIRED",
        discount_percent=10,
        valid_until=datetime.now(timezone.utc) + timedelta(days=1),
    )

    resp = await client.post(
        "/promo/validate", json={"code": promo.code, "cart_total": 1000}
    )
    assert resp.status_code == 200


async def test_usage_limit_exceeded_rejected(client: AsyncClient):
    promo = await _make_promo(
        "LIMITED", discount_percent=10, max_uses=5, used_count=5
    )

    resp = await client.post(
        "/promo/validate", json={"code": promo.code, "cart_total": 1000}
    )
    assert resp.status_code == 422


async def test_usage_below_limit_is_accepted(client: AsyncClient):
    promo = await _make_promo(
        "UNDERLIMIT", discount_percent=10, max_uses=5, used_count=4
    )

    resp = await client.post(
        "/promo/validate", json={"code": promo.code, "cart_total": 1000}
    )
    assert resp.status_code == 200


async def test_inactive_promo_rejected(client: AsyncClient):
    promo = await _make_promo("INACTIVE", discount_percent=10, is_active=False)

    resp = await client.post(
        "/promo/validate", json={"code": promo.code, "cart_total": 1000}
    )
    assert resp.status_code == 422


async def test_validate_requires_positive_cart_total(client: AsyncClient):
    resp = await client.post(
        "/promo/validate", json={"code": "ANY", "cart_total": 0}
    )
    assert resp.status_code == 422
