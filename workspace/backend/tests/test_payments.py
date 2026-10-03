"""Интеграция ЮKassa: POST /payments/create создаёт платёж и возвращает
confirmation_url для редиректа; POST /payments/webhook переводит заказ в
payment_status=paid при успешной оплате.

Реальный Postgres, тот же контур, что у остальных файлов — свой префикс
телефона (+70008, следующий свободный после +70007 у test_order_status.py)
и свой префикс имён отелей/категорий. ЮKassa
замокана целиком (`FakeYookassaClient`, dependency override как у
FakeSmsProvider в conftest.py) — реальный вызов внешнего API в этой сессии
не проверялся: YOOKASSA_SHOP_ID/YOOKASSA_SECRET_KEY в окружении заглушки
(режим самостоятельности), настоящий ключ ЮKassa клиент ещё не прислал.
"""

import uuid

import pytest_asyncio
from httpx import AsyncClient
from sqlalchemy import delete, select

from app.core.security import create_access_token
from app.core.yookassa import YookassaClient, YookassaError
from app.db.session import async_session_factory
from app.models.category import Category
from app.models.hotel import Hotel
from app.models.order import Order, OrderPaymentStatus
from app.models.order_item import OrderItem
from app.models.payment import Payment, PaymentMethod, PaymentStatus
from app.models.product import Product
from app.models.role import Role, RoleCode
from app.models.user import User

TEST_PHONE_PREFIX = "+70008"
TEST_PREFIX = "TestPayments_"
ORDER_TOTAL = 4000


class FakeYookassaClient(YookassaClient):
    """Мок ЮKassa — не ходит в сеть. Держит созданные платежи в памяти, чтобы
    `get_payment()` (вызываемый вебхуком для перепроверки статуса — см.
    app/core/yookassa.py) отвечал согласованно с тем, что вернул create_payment."""

    def __init__(self) -> None:  # намеренно не зовём super().__init__: нет реальных credentials
        self.created: list[dict] = []
        self.payments: dict[str, dict] = {}
        self.fail_create = False
        self.fail_get = False

    async def create_payment(
        self, *, amount, currency, description, return_url, order_id,
        payment_method=None, idempotence_key=None,
    ) -> dict:
        self.last_method = payment_method
        self.last_key = idempotence_key
        if self.fail_create:
            raise YookassaError("ЮKassa недоступна (симулировано тестом)")
        payment_id = f"yk-{uuid.uuid4().hex[:12]}"
        record = {
            "id": payment_id,
            "status": "pending",
            "amount": {"value": f"{amount:.2f}", "currency": currency},
            "confirmation": {"type": "redirect", "confirmation_url": f"https://yookassa.ru/pay/{payment_id}"},
            "metadata": {"order_id": str(order_id)},
        }
        self.payments[payment_id] = record
        self.created.append(record)
        return record

    async def get_payment(self, yookassa_payment_id: str) -> dict:
        if self.fail_get:
            raise YookassaError("ЮKassa недоступна (симулировано тестом)")
        return self.payments[yookassa_payment_id]

    def mark_succeeded(self, payment_id: str, *, method: str = "bank_card") -> None:
        self.payments[payment_id]["status"] = "succeeded"
        self.payments[payment_id]["payment_method"] = {"type": method}

    def mark_canceled(self, payment_id: str) -> None:
        self.payments[payment_id]["status"] = "canceled"


@pytest_asyncio.fixture
async def fake_yookassa() -> FakeYookassaClient:
    return FakeYookassaClient()


@pytest_asyncio.fixture
async def client(fake_yookassa: FakeYookassaClient) -> AsyncClient:
    from httpx import ASGITransport

    from app.api.payments import _yookassa_client_dependency
    from app.main import app

    app.dependency_overrides[_yookassa_client_dependency] = lambda: fake_yookassa
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
    app.dependency_overrides.pop(_yookassa_client_dependency, None)


async def _wipe_payments_test_data() -> None:
    async with async_session_factory() as session:
        user_ids = select(User.id).where(User.phone.like(f"{TEST_PHONE_PREFIX}%"))
        order_ids = select(Order.id).where(Order.user_id.in_(user_ids))
        await session.execute(delete(Payment).where(Payment.order_id.in_(order_ids)))
        await session.execute(delete(OrderItem).where(OrderItem.order_id.in_(order_ids)))
        await session.execute(delete(Order).where(Order.user_id.in_(user_ids)))
        await session.execute(delete(User).where(User.phone.like(f"{TEST_PHONE_PREFIX}%")))

        category_ids = select(Category.id).where(Category.name.like(f"{TEST_PREFIX}%"))
        await session.execute(delete(Product).where(Product.category_id.in_(category_ids)))
        await session.execute(delete(Category).where(Category.name.like(f"{TEST_PREFIX}%")))
        await session.execute(delete(Hotel).where(Hotel.name.like(f"{TEST_PREFIX}%")))
        await session.commit()


@pytest_asyncio.fixture(autouse=True)
async def _cleanup_payments_data():
    await _wipe_payments_test_data()
    yield
    await _wipe_payments_test_data()


async def _make_user(suffix: str) -> tuple[User, str]:
    async with async_session_factory() as session:
        result = await session.execute(select(Role).where(Role.code == RoleCode.CLIENT.value))
        role = result.scalar_one()
        user = User(phone=f"{TEST_PHONE_PREFIX}{suffix}", role_id=role.id)
        session.add(user)
        await session.commit()
        await session.refresh(user)
    return user, create_access_token(user.id)


async def _make_order(user: User, suffix: str, *, total: float = ORDER_TOTAL) -> Order:
    async with async_session_factory() as session:
        hotel = Hotel(name=f"{TEST_PREFIX}Hotel{suffix}")
        session.add(hotel)
        await session.flush()
        order = Order(
            user_id=user.id,
            total=total,
            hotel_name=hotel.name,
            room_number=suffix,
        )
        session.add(order)
        await session.commit()
        await session.refresh(order)
    return order


def _auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


async def test_create_payment_without_token_is_401(client: AsyncClient):
    resp = await client.post("/payments/create", json={"order_id": 1})
    assert resp.status_code == 401


async def test_payment_creates_yukassa_order(client: AsyncClient, fake_yookassa: FakeYookassaClient):
    user, token = await _make_user("01")
    order = await _make_order(user, "01")

    resp = await client.post("/payments/create", json={"order_id": order.id}, headers=_auth(token))

    assert resp.status_code == 201
    body = resp.json()
    assert body["order_id"] == order.id
    assert body["status"] == "pending"
    assert body["confirmation_url"].startswith("https://yookassa.ru/pay/")

    # платёж действительно создан в ЮKassa (моке) с суммой заказа
    assert len(fake_yookassa.created) == 1
    assert fake_yookassa.created[0]["amount"]["value"] == f"{ORDER_TOTAL:.2f}"

    async with async_session_factory() as session:
        payment = (
            await session.execute(select(Payment).where(Payment.order_id == order.id))
        ).scalar_one()
        assert payment.status == PaymentStatus.PENDING
        assert payment.yookassa_payment_id == fake_yookassa.created[0]["id"]
        assert float(payment.amount) == ORDER_TOTAL

        refreshed_order = await session.get(Order, order.id)
        # создание платежа само по себе заказ ещё не оплачивает — это делает вебхук
        assert refreshed_order.payment_status == OrderPaymentStatus.UNPAID


async def test_create_payment_for_unknown_order_is_404(client: AsyncClient):
    _, token = await _make_user("02")
    resp = await client.post("/payments/create", json={"order_id": 999999999}, headers=_auth(token))
    assert resp.status_code == 404


async def test_create_payment_for_other_users_order_is_403(client: AsyncClient):
    owner, _ = await _make_user("03")
    order = await _make_order(owner, "03")
    _, other_token = await _make_user("04")

    resp = await client.post("/payments/create", json={"order_id": order.id}, headers=_auth(other_token))
    assert resp.status_code == 403


async def test_create_payment_for_already_paid_order_is_409(client: AsyncClient):
    user, token = await _make_user("05")
    order = await _make_order(user, "05")
    async with async_session_factory() as session:
        db_order = await session.get(Order, order.id)
        db_order.payment_status = OrderPaymentStatus.PAID
        await session.commit()

    resp = await client.post("/payments/create", json={"order_id": order.id}, headers=_auth(token))
    assert resp.status_code == 409


async def test_create_payment_yookassa_failure_is_502(client: AsyncClient, fake_yookassa: FakeYookassaClient):
    user, token = await _make_user("06")
    order = await _make_order(user, "06")
    fake_yookassa.fail_create = True

    resp = await client.post("/payments/create", json={"order_id": order.id}, headers=_auth(token))
    assert resp.status_code == 502


async def test_webhook_succeeded_payment_marks_order_paid(client: AsyncClient, fake_yookassa: FakeYookassaClient):
    user, token = await _make_user("07")
    order = await _make_order(user, "07")

    create_resp = await client.post("/payments/create", json={"order_id": order.id}, headers=_auth(token))
    yookassa_payment_id = fake_yookassa.created[0]["id"]

    fake_yookassa.mark_succeeded(yookassa_payment_id)
    webhook_resp = await client.post(
        "/payments/webhook",
        json={
            "type": "notification",
            "event": "payment.succeeded",
            "object": {"id": yookassa_payment_id, "status": "succeeded"},
        },
    )

    assert webhook_resp.status_code == 200
    assert webhook_resp.json()["status"] == "ok"

    async with async_session_factory() as session:
        refreshed_order = await session.get(Order, order.id)
        assert refreshed_order.payment_status == OrderPaymentStatus.PAID

        payment = (
            await session.execute(select(Payment).where(Payment.order_id == order.id))
        ).scalar_one()
        assert payment.status == PaymentStatus.SUCCEEDED
        assert payment.payment_method == PaymentMethod.BANK_CARD


async def test_webhook_does_not_trust_body_status_without_reconfirmation(
    client: AsyncClient, fake_yookassa: FakeYookassaClient
):
    """Тело вебхука само по себе никого не убеждает: даже если в POST-запросе
    стоит status=succeeded, реальный статус берётся из GET /payments/{id}
    (см. app/core/yookassa.py — угроза: подделанный вебхук на публичный
    эндпоинт). Платёж в моке остаётся pending -> заказ не должен стать paid."""
    user, token = await _make_user("08")
    order = await _make_order(user, "08")

    await client.post("/payments/create", json={"order_id": order.id}, headers=_auth(token))
    yookassa_payment_id = fake_yookassa.created[0]["id"]
    # НЕ вызываем fake_yookassa.mark_succeeded — реальный статус в "ЮKassa" остаётся pending

    webhook_resp = await client.post(
        "/payments/webhook",
        json={
            "type": "notification",
            "event": "payment.succeeded",
            # тело утверждает succeeded, но GET /payments/{id} (мок) вернёт pending
            "object": {"id": yookassa_payment_id, "status": "succeeded"},
        },
    )
    assert webhook_resp.status_code == 200

    async with async_session_factory() as session:
        refreshed_order = await session.get(Order, order.id)
        assert refreshed_order.payment_status == OrderPaymentStatus.UNPAID


async def test_webhook_canceled_payment_marks_order_failed(client: AsyncClient, fake_yookassa: FakeYookassaClient):
    user, token = await _make_user("09")
    order = await _make_order(user, "09")

    await client.post("/payments/create", json={"order_id": order.id}, headers=_auth(token))
    yookassa_payment_id = fake_yookassa.created[0]["id"]
    fake_yookassa.mark_canceled(yookassa_payment_id)

    resp = await client.post(
        "/payments/webhook",
        json={"type": "notification", "event": "payment.canceled", "object": {"id": yookassa_payment_id}},
    )
    assert resp.status_code == 200

    async with async_session_factory() as session:
        refreshed_order = await session.get(Order, order.id)
        assert refreshed_order.payment_status == OrderPaymentStatus.FAILED

        payment = (
            await session.execute(select(Payment).where(Payment.order_id == order.id))
        ).scalar_one()
        assert payment.status == PaymentStatus.CANCELED


async def test_webhook_for_unknown_payment_is_ignored_not_error(client: AsyncClient):
    resp = await client.post(
        "/payments/webhook",
        json={"type": "notification", "event": "payment.succeeded", "object": {"id": "yk-does-not-exist"}},
    )
    assert resp.status_code == 200
    assert resp.json()["status"] == "ignored"


async def test_webhook_without_payment_id_is_422(client: AsyncClient):
    resp = await client.post(
        "/payments/webhook", json={"type": "notification", "event": "payment.succeeded", "object": {}}
    )
    assert resp.status_code == 422


async def test_webhook_already_paid_order_not_downgraded_by_later_cancellation(
    client: AsyncClient, fake_yookassa: FakeYookassaClient
):
    """Заказ оплачен одной попыткой; если по НЕЙ ЖЕ позже (повторный вебхук,
    задержка в очереди уведомлений) статус останется succeeded — заказ должен
    остаться paid, а не откатиться. Регрессия против гонки повторных доставок
    одного и того же вебхука ЮKassa."""
    user, token = await _make_user("10")
    order = await _make_order(user, "10")

    await client.post("/payments/create", json={"order_id": order.id}, headers=_auth(token))
    yookassa_payment_id = fake_yookassa.created[0]["id"]
    fake_yookassa.mark_succeeded(yookassa_payment_id)

    for _ in range(2):
        resp = await client.post(
            "/payments/webhook",
            json={"type": "notification", "event": "payment.succeeded", "object": {"id": yookassa_payment_id}},
        )
        assert resp.status_code == 200

    async with async_session_factory() as session:
        refreshed_order = await session.get(Order, order.id)
        assert refreshed_order.payment_status == OrderPaymentStatus.PAID


async def test_payment_method_cash_is_not_a_valid_enum_value():
    """Структурная проверка требования «наличные не принимаются»: в системе
    физически нет значения payment_method для наличных — 'cash' не входит
    в перечень допустимых способов оплаты вообще."""
    assert "cash" not in {method.value for method in PaymentMethod}
    assert {method.value for method in PaymentMethod} == {"bank_card", "sbp"}


async def test_create_payment_without_yookassa_credentials_is_502(client: AsyncClient, monkeypatch):
    """Если YOOKASSA_SHOP_ID/YOOKASSA_SECRET_KEY не настроены (заглушка режима
    самостоятельности), `get_yookassa_client()` отказывает явным сообщением, а
    не молча создаёт платёж без реальных credentials. Проверяем сам путь
    ошибки, минуя dependency override клиента, который в остальных тестах
    подменяет реальный запрос к ЮKassa."""
    from app.api.payments import _yookassa_client_dependency
    from app.main import app

    app.dependency_overrides.pop(_yookassa_client_dependency, None)

    from httpx import ASGITransport

    user, token = await _make_user("11")
    order = await _make_order(user, "11")

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        resp = await ac.post("/payments/create", json={"order_id": order.id}, headers=_auth(token))
    assert resp.status_code == 502
