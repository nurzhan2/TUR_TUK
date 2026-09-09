"""Push-уведомления: клиенту при смене статуса заказа, администратору и
свободным курьерам при создании нового заказа.

Мокается только интерфейс `NotificationSender` (`FakeNotificationSender`,
dependency override — тот же приём, что `FakeSmsProvider` в conftest.py и
`FakeYookassaClient` в test_payments.py), а не FCM API: реальный вызов
`fcm.googleapis.com` в этой сессии не проверялся, FCM_SERVER_KEY в окружении
пуст (владелец ещё не подключил Firebase — см. бриф).

Реальный Postgres, тот же контур, что у остальных файлов — свой префикс
телефона (+70010, следующий свободный после +70009 у test_order_history.py).
"""

import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy import delete, select

from app.core.notifications import NotificationSender
from app.core.security import create_access_token
from app.db.session import async_session_factory
from app.models.category import Category
from app.models.hotel import Hotel
from app.models.order import Order, OrderStatus
from app.models.order_item import OrderItem
from app.models.order_status_log import OrderStatusLog
from app.models.product import Product
from app.models.role import Role, RoleCode
from app.models.user import User

TEST_PHONE_PREFIX = "+70010"
TEST_PREFIX = "TestPush_"


class FakeNotificationSender(NotificationSender):
    """Мок `NotificationSender` — не ходит в сеть, запоминает вызовы."""

    def __init__(self) -> None:
        self.sent: list[tuple[int, str, str]] = []

    async def send(self, user_id: int, title: str, body: str) -> None:
        self.sent.append((user_id, title, body))

    def sent_to(self, user_id: int) -> list[tuple[str, str]]:
        return [(title, body) for uid, title, body in self.sent if uid == user_id]


@pytest_asyncio.fixture
async def fake_notification_sender() -> FakeNotificationSender:
    return FakeNotificationSender()


@pytest_asyncio.fixture
async def client(fake_notification_sender: FakeNotificationSender) -> AsyncClient:
    from app.api.orders import _notification_sender_dependency
    from app.main import app

    app.dependency_overrides[_notification_sender_dependency] = lambda: fake_notification_sender
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
    app.dependency_overrides.pop(_notification_sender_dependency, None)


async def _wipe_push_test_data() -> None:
    async with async_session_factory() as session:
        user_ids = select(User.id).where(User.phone.like(f"{TEST_PHONE_PREFIX}%"))
        order_ids = select(Order.id).where(
            Order.user_id.in_(user_ids) | Order.courier_id.in_(user_ids)
        )
        await session.execute(delete(OrderStatusLog).where(OrderStatusLog.order_id.in_(order_ids)))
        await session.execute(delete(OrderItem).where(OrderItem.order_id.in_(order_ids)))
        await session.execute(delete(Order).where(Order.id.in_(order_ids)))
        await session.execute(delete(User).where(User.phone.like(f"{TEST_PHONE_PREFIX}%")))

        category_ids = select(Category.id).where(Category.name.like(f"{TEST_PREFIX}%"))
        await session.execute(delete(Product).where(Product.category_id.in_(category_ids)))
        await session.execute(delete(Category).where(Category.name.like(f"{TEST_PREFIX}%")))
        await session.execute(delete(Hotel).where(Hotel.name.like(f"{TEST_PREFIX}%")))
        await session.commit()


@pytest_asyncio.fixture(autouse=True)
async def _cleanup_push_data():
    await _wipe_push_test_data()
    yield
    await _wipe_push_test_data()


async def _make_user(role_code: str, suffix: str) -> tuple[User, str]:
    async with async_session_factory() as session:
        result = await session.execute(select(Role).where(Role.code == role_code))
        role = result.scalar_one()
        user = User(phone=f"{TEST_PHONE_PREFIX}{suffix}", role_id=role.id)
        session.add(user)
        await session.commit()
        await session.refresh(user)
    return user, create_access_token(user.id)


async def _make_order(*, user_id: int, courier_id: int | None = None,
                       status_: OrderStatus = OrderStatus.CREATED) -> Order:
    async with async_session_factory() as session:
        order = Order(
            user_id=user_id,
            courier_id=courier_id,
            status=status_,
            total=3500,
            hotel_name="Test Hotel",
            room_number="101",
        )
        session.add(order)
        await session.commit()
        await session.refresh(order)
    return order


async def _make_hotel(name: str) -> Hotel:
    async with async_session_factory() as session:
        hotel = Hotel(name=f"{TEST_PREFIX}{name}")
        session.add(hotel)
        await session.commit()
        await session.refresh(hotel)
    return hotel


async def _make_category(name: str) -> Category:
    async with async_session_factory() as session:
        category = Category(name=f"{TEST_PREFIX}{name}")
        session.add(category)
        await session.commit()
        await session.refresh(category)
    return category


async def _make_product(name: str, category_id: int, *, price: float = 4000) -> Product:
    async with async_session_factory() as session:
        product = Product(
            name=f"{TEST_PREFIX}{name}",
            description="описание",
            price=price,
            category_id=category_id,
            is_available=True,
        )
        session.add(product)
        await session.commit()
        await session.refresh(product)
    return product


def _auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


async def _patch_status(client, order_id: int, token: str, new_status: str):
    return await client.patch(
        f"/orders/{order_id}/status",
        json={"status": new_status},
        headers=_auth(token),
    )


# --- смена статуса заказа уведомляет клиента ----------------------------


async def test_push_sent_on_status_change(client, fake_notification_sender):
    client_user, _ = await _make_user(RoleCode.CLIENT.value, "010")
    courier, courier_token = await _make_user(RoleCode.COURIER.value, "011")
    order = await _make_order(user_id=client_user.id)

    resp = await _patch_status(client, order.id, courier_token, "accepted")
    assert resp.status_code == 200

    sent = fake_notification_sender.sent_to(client_user.id)
    assert len(sent) == 1
    title, body = sent[0]
    assert str(order.id) in title
    assert "принят" in title


async def test_push_sent_for_every_client_facing_status(client, fake_notification_sender):
    client_user, _ = await _make_user(RoleCode.CLIENT.value, "020")
    courier, courier_token = await _make_user(RoleCode.COURIER.value, "021")
    _, admin_token = await _make_user(RoleCode.ADMIN.value, "022")
    order = await _make_order(user_id=client_user.id, courier_id=courier.id)

    # Тот же граф ролей, что в test_order_status.py::test_full_transition_
    # happy_path_records_history: courier принимает, admin/collector собирает,
    # дальше снова только назначенный курьер.
    resp = await _patch_status(client, order.id, courier_token, "accepted")
    assert resp.status_code == 200
    resp = await _patch_status(client, order.id, admin_token, "assembling")
    assert resp.status_code == 200
    for target in ("delivering", "delivered"):
        resp = await _patch_status(client, order.id, courier_token, target)
        assert resp.status_code == 200

    sent = fake_notification_sender.sent_to(client_user.id)
    assert len(sent) == 4
    assert all(str(order.id) in title for title, _ in sent)


async def test_push_not_sent_on_rejection(client, fake_notification_sender):
    """CANCELLED не входит в перечень статусов, о которых бриф просит слать
    push клиенту («принят/собирается/доставляется/доставлен»)."""
    client_user, _ = await _make_user(RoleCode.CLIENT.value, "030")
    _, admin_token = await _make_user(RoleCode.ADMIN.value, "031")
    order = await _make_order(user_id=client_user.id)

    resp = await _patch_status(client, order.id, admin_token, "cancelled")
    assert resp.status_code == 200
    assert fake_notification_sender.sent_to(client_user.id) == []


# --- новый заказ уведомляет администратора и свободных курьеров ----------


async def test_new_order_notifies_admin_and_free_couriers(client, fake_notification_sender):
    client_user, client_token = await _make_user(RoleCode.CLIENT.value, "040")
    admin, _ = await _make_user(RoleCode.ADMIN.value, "041")
    free_courier, _ = await _make_user(RoleCode.COURIER.value, "042")
    busy_courier, _ = await _make_user(RoleCode.COURIER.value, "043")
    # курьер занят активной доставкой другого заказа — не считается свободным
    await _make_order(user_id=client_user.id, courier_id=busy_courier.id,
                       status_=OrderStatus.DELIVERING)

    hotel = await _make_hotel("Hotel040")
    category = await _make_category("Category040")
    product = await _make_product("Product040", category.id)

    resp = await client.post(
        "/orders",
        json={
            "hotel_name": hotel.name,
            "room_number": "40",
            "items": [{"product_id": product.id, "quantity": 1}],
        },
        headers=_auth(client_token),
    )
    assert resp.status_code == 201
    order_id = resp.json()["id"]

    notified_ids = {uid for uid, _, _ in fake_notification_sender.sent}
    assert admin.id in notified_ids
    assert free_courier.id in notified_ids
    assert busy_courier.id not in notified_ids
    assert all(str(order_id) in title for uid, title, _ in fake_notification_sender.sent
               if uid in (admin.id, free_courier.id))


async def test_free_courier_becomes_notifiable_after_delivery_completed(client, fake_notification_sender):
    """Курьер, завершивший доставку (DELIVERED), снова считается свободным."""
    client_user, _ = await _make_user(RoleCode.CLIENT.value, "050")
    courier, _ = await _make_user(RoleCode.COURIER.value, "051")
    await _make_order(user_id=client_user.id, courier_id=courier.id,
                       status_=OrderStatus.DELIVERED)

    order = await _make_order(user_id=client_user.id, status_=OrderStatus.CREATED)
    from app.services.order_notifications import notify_new_order

    await notify_new_order(
        fake_notification_sender,
        order_id=order.id,
        hotel_name=order.hotel_name,
        room_number=order.room_number,
        total=float(order.total),
    )

    notified_ids = {uid for uid, _, _ in fake_notification_sender.sent}
    assert courier.id in notified_ids


# --- отсутствие настроенного провайдера не блокирует заказ ---------------


async def test_status_update_works_without_configured_notification_provider():
    """FCM_SERVER_KEY не задан (заглушка режима самостоятельности) —
    `_notification_sender_dependency` отдаёт `None`, но смена статуса
    заказа не должна из-за этого падать: push — сопутствующий эффект,
    а не условие успеха самой операции."""
    from app.api.orders import _notification_sender_dependency
    from app.main import app

    app.dependency_overrides.pop(_notification_sender_dependency, None)

    client_user, _ = await _make_user(RoleCode.CLIENT.value, "060")
    _, admin_token = await _make_user(RoleCode.ADMIN.value, "061")
    order = await _make_order(user_id=client_user.id)

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        resp = await _patch_status(ac, order.id, admin_token, "accepted")
    assert resp.status_code == 200
