"""Заказы: доступ по владению, а не только по факту авторизации.

Требование задачи буквально — «курьер не имеет доступа к заказам других
курьеров». Симметрично распространено на клиента: клиент не видит чужие
заказы. Персонал (`STAFF_ROLES`) заказ ведёт по должности и видит все —
иначе поддержка не смогла бы найти заказ клиента, который сам не курьер
и не автор запроса.
"""

from fastapi import APIRouter, BackgroundTasks, Depends, File, HTTPException, UploadFile, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.promo import compute_discount, get_valid_promo
from app.core.config import get_settings
from app.core.deps import get_current_user
from app.core.notifications import NotificationSender, NotificationSendError, get_notification_sender
from app.core.rbac import ADMIN_ROLES, STAFF_ROLES
from app.db.session import get_session
from app.models.hotel import Hotel
from app.models.order import Order, OrderStatus
from app.models.order_item import OrderItem
from app.models.order_status_log import OrderStatusLog
from app.models.product import Product
from app.models.role import RoleCode
from app.models.user import User
from app.schemas.order import (
    OrderCreate,
    OrderHistoryItemOut,
    OrderHistoryOut,
    OrderOut,
    OrderStatusUpdate,
    RepeatOrderOut,
    RepeatSkippedItem,
)
from app.services.app_settings import delivery_fee_for, load_settings, min_order_total
from app.services.order_notifications import notify_new_order, notify_order_status_changed
from app.services.storage import store_image

router = APIRouter(prefix="/orders", tags=["orders"])

# Запасное значение минимальной суммы: действующее берётся из настроек админки.
MIN_ORDER_TOTAL = 3000.0

_AVAILABLE = Product.is_available.is_(True)

# Граф допустимых переходов статуса (задача «Управление статусами заказа»).
# Из DELIVERED и CANCELLED переходов нет — оба терминальные.
_ALLOWED_TRANSITIONS: dict[OrderStatus, set[OrderStatus]] = {
    OrderStatus.CREATED: {OrderStatus.ACCEPTED, OrderStatus.CANCELLED},
    OrderStatus.ACCEPTED: {OrderStatus.ASSEMBLING},
    OrderStatus.ASSEMBLING: {OrderStatus.DELIVERING},
    OrderStatus.DELIVERING: {OrderStatus.DELIVERED},
}

# «Только courier/admin принимает/отклоняет» — задача не различает буквальное
# "pending"/"rejected" от уже действующих в схеме "created"/"cancelled" (тот
# же приём, что уже задокументирован для статуса нового заказа в
# docs/DECISIONS.md: заводить второе имя под то же состояние не стали).
_ACCEPT_REJECT_ROLES = {RoleCode.COURIER.value, *ADMIN_ROLES}
# «Только admin/collector меняет assembling» — SUPPORT сюда намеренно не входит,
# формулировка задачи называет только эти две роли.
_ASSEMBLING_ROLES = {*ADMIN_ROLES, RoleCode.COLLECTOR.value}
# «Только курьер меняет delivering/delivered».
_COURIER_ONLY_ROLES = {RoleCode.COURIER.value}

_STATUS_ROLES: dict[OrderStatus, set[str]] = {
    OrderStatus.ACCEPTED: _ACCEPT_REJECT_ROLES,
    OrderStatus.CANCELLED: _ACCEPT_REJECT_ROLES,
    OrderStatus.ASSEMBLING: _ASSEMBLING_ROLES,
    OrderStatus.DELIVERING: _COURIER_ONLY_ROLES,
    OrderStatus.DELIVERED: _COURIER_ONLY_ROLES,
}


def _notification_sender_dependency() -> NotificationSender | None:
    """Отдельная функция — точка, которую тесты подменяют через
    `app.dependency_overrides` (тот же приём, что `_sms_provider_dependency`
    в `app/api/auth.py`).

    В отличие от SMS и ЮKassa, отсутствие настроенного провайдера НЕ блокирует
    создание/обновление заказа ошибкой: push-уведомление — сопутствующий
    эффект операции с заказом, а не сама операция, и его нельзя ронять из-за
    того, что провайдер push ещё не выбран владельцем окончательно (см. бриф,
    open_question). `None` значит «уведомлять пока нечем» — вызывающий код
    просто не планирует фоновую задачу.
    """
    try:
        return get_notification_sender()
    except NotificationSendError:
        return None


def _can_view(user: User, order: Order) -> bool:
    role = user.role.code
    if role in STAFF_ROLES:
        return True
    if role == RoleCode.COURIER.value:
        return order.courier_id == user.id
    # клиент и любая другая роль без явного расширения — только свой заказ
    return order.user_id == user.id


@router.post("", response_model=OrderOut, status_code=status.HTTP_201_CREATED)
async def create_order(
    payload: OrderCreate,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
    notification_sender: NotificationSender | None = Depends(_notification_sender_dependency),
) -> Order:
    """Оформление заказа: зона доставки, минимальная сумма, промокод.

    `hotel_name` сверяется со справочником `hotels` регистронезависимо —
    тот же приём, что уже применён в `POST /auth/register`; хранится
    каноническое `hotel.name` из БД, а не то, что набрал клиент.
    """
    hotel = (
        await session.execute(
            select(Hotel).where(func.lower(Hotel.name) == payload.hotel_name.lower())
        )
    ).scalar_one_or_none()
    if hotel is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="отель вне зоны доставки",
        )

    product_ids = [item.product_id for item in payload.items]
    result = await session.execute(select(Product).where(Product.id.in_(product_ids), _AVAILABLE))
    products_by_id = {product.id: product for product in result.scalars().all()}
    missing_ids = [pid for pid in product_ids if pid not in products_by_id]
    if missing_ids:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="товар не найден")

    # Единая цена товара — `Product.price` из каталога, ни от чего кроме
    # самого товара не зависит: намеренно нет множителя по hotel_name/району
    # (бриф, curated: «Единая цена товара — не зависит от hotel_name»).
    subtotal = sum(
        float(products_by_id[item.product_id].price) * item.quantity for item in payload.items
    )
    # Порог считается ДО промокода: скидка не должна давать возможность
    # обойти минимальную сумму заказа, которую иначе можно набрать честно.
    # Минимум и доставка — из настроек админки, не из кода.
    app_settings = await load_settings(session)
    min_total = min_order_total(app_settings)
    if subtotal < min_total:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"минимальная сумма заказа — {min_total:.0f} ₽",
        )

    promo = None
    discount = 0.0
    if payload.promo_code:
        promo = await get_valid_promo(session, payload.promo_code)
        discount = compute_discount(promo, subtotal)

    # Бесплатная доставка — по сумме товаров до скидки, как показывает приложение.
    delivery_fee = delivery_fee_for(app_settings, subtotal)

    order = Order(
        user_id=current_user.id,
        status=OrderStatus.CREATED,
        subtotal=subtotal,
        discount=discount,
        delivery_fee=delivery_fee,
        total=subtotal - discount + delivery_fee,
        payment_method=payload.payment_method,
        hotel_name=hotel.name,
        room_number=payload.room_number,
        promo_id=promo.id if promo is not None else None,
    )
    session.add(order)
    await session.flush()

    for item in payload.items:
        product = products_by_id[item.product_id]
        session.add(
            OrderItem(
                order_id=order.id,
                product_id=product.id,
                quantity=item.quantity,
                price=product.price,
            )
        )

    if promo is not None:
        # Списание лимита — дело оформления заказа, не проверки в корзине
        # (см. app/api/promo.py).
        promo.used_count += 1

    await session.commit()
    await session.refresh(order)

    if notification_sender is not None:
        # Новый заказ — администратору и свободным курьерам (бриф,
        # deliverable «Уведомления: новый заказ...»). Фоновая задача: не
        # задерживает и не может провалить сам ответ на создание заказа.
        background_tasks.add_task(
            notify_new_order,
            notification_sender,
            order_id=order.id,
            hotel_name=order.hotel_name,
            room_number=order.room_number,
            total=float(order.total),
        )

    return order


@router.get("", response_model=list[OrderOut])
async def list_orders(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> list[Order]:
    role = current_user.role.code
    query = select(Order).order_by(Order.id)
    if role == RoleCode.COURIER.value:
        query = query.where(Order.courier_id == current_user.id)
    elif role not in STAFF_ROLES:
        query = query.where(Order.user_id == current_user.id)
    result = await session.execute(query)
    return list(result.scalars().all())


def _history_out(order: Order) -> OrderHistoryOut:
    """Собирается ВРУЧНУЮ, а не через `from_attributes`: `product_name`
    в `OrderHistoryItemOut` не совпадает по имени с атрибутом ORM
    (`item.product.name`), а pydantic не проходит по цепочке атрибутов
    сам — тот же приём, что `_to_out()` в `app/api/cart.py`."""
    return OrderHistoryOut(
        id=order.id,
        user_id=order.user_id,
        courier_id=order.courier_id,
        status=order.status,
        total=float(order.total),
        hotel_name=order.hotel_name,
        room_number=order.room_number,
        delivery_photo_url=order.delivery_photo_url,
        created_at=order.created_at,
        items=[
            OrderHistoryItemOut(
                product_id=item.product_id,
                product_name=item.product.name,
                quantity=item.quantity,
                price=float(item.price),
            )
            for item in order.items
        ],
    )


@router.get("/history", response_model=list[OrderHistoryOut])
async def order_history(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> list[OrderHistoryOut]:
    """История заказов с деталями (бриф, deliverable «История заказов клиента
    с возможностью повторить заказ»), новые сверху.

    Регистрируется РАНЬШЕ `GET /{order_id}`: тот же путь `/history` со
    строкой вместо числового `order_id` иначе никогда бы не дошёл до этого
    обработчика — FastAPI матчит маршруты в порядке регистрации, и
    `/{order_id}: int` забрал бы его первым, ответив 422 вместо истории.

    Область видимости — та же, что у `list_orders`: клиент видит свои
    заказы, курьер — назначенные ему, персонал (`STAFF_ROLES`) — все.
    """
    role = current_user.role.code
    query = (
        select(Order)
        .options(selectinload(Order.items).selectinload(OrderItem.product))
        .order_by(Order.created_at.desc())
    )
    if role == RoleCode.COURIER.value:
        query = query.where(Order.courier_id == current_user.id)
    elif role not in STAFF_ROLES:
        query = query.where(Order.user_id == current_user.id)
    result = await session.execute(query)
    return [_history_out(order) for order in result.unique().scalars().all()]


@router.post("/{order_id}/repeat", response_model=RepeatOrderOut)
async def repeat_order(
    order_id: int,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> RepeatOrderOut:
    """Повтор заказа: новый заказ из позиций старого, с проверкой наличия.

    Повторить вправе только САМ АВТОР заказа, без исключения для персонала
    (тот же принцип, что у оплаты в `app/api/payments.py`, а не у `_can_view`):
    новый заказ создаётся от имени того, кто нажал «повторить», и заказ
    персонала с чужими hotel_name/room_number от чужого лица — не тот
    сценарий, который просила задача.

    Недоступный товар не проваливает всю операцию — он выпадает из повтора,
    а `skipped_items`/`warning` называют, что именно и почему. Ответ 422,
    если результат повторить нечем (все товары недоступны) или доступного
    не хватает на минимальную сумму заказа — те же правила, что у создания
    заказа с нуля.
    """
    result = await session.execute(
        select(Order)
        .options(selectinload(Order.items).selectinload(OrderItem.product))
        .where(Order.id == order_id)
    )
    order = result.scalar_one_or_none()
    if order is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="заказ не найден")
    if order.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="повторить можно только свой заказ",
        )

    product_ids = [item.product_id for item in order.items]
    available_result = await session.execute(
        select(Product).where(Product.id.in_(product_ids), _AVAILABLE)
    )
    available_by_id = {product.id: product for product in available_result.scalars().all()}

    skipped: list[RepeatSkippedItem] = []
    to_create: list[tuple[Product, int]] = []
    subtotal = 0.0
    for item in order.items:
        product = available_by_id.get(item.product_id)
        if product is None:
            skipped.append(
                RepeatSkippedItem(product_id=item.product_id, product_name=item.product.name)
            )
            continue
        subtotal += float(product.price) * item.quantity
        to_create.append((product, item.quantity))

    if not to_create:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="ни один товар из заказа не доступен для повтора",
        )
    app_settings = await load_settings(session)
    min_total = min_order_total(app_settings)
    if subtotal < min_total:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"доступных товаров недостаточно для минимальной суммы заказа — {min_total:.0f} ₽",
        )

    delivery_fee = delivery_fee_for(app_settings, subtotal)
    new_order = Order(
        user_id=current_user.id,
        status=OrderStatus.CREATED,
        subtotal=subtotal,
        delivery_fee=delivery_fee,
        total=subtotal + delivery_fee,
        payment_method=order.payment_method,
        hotel_name=order.hotel_name,
        room_number=order.room_number,
    )
    session.add(new_order)
    await session.flush()
    for product, quantity in to_create:
        session.add(
            OrderItem(
                order_id=new_order.id,
                product_id=product.id,
                quantity=quantity,
                price=product.price,
            )
        )
    await session.commit()
    await session.refresh(new_order)

    warning = None
    if skipped:
        names = ", ".join(item.product_name for item in skipped)
        warning = f"недоступны и не включены в повтор: {names}"

    return RepeatOrderOut(
        order=OrderOut.model_validate(new_order),
        skipped_items=skipped,
        warning=warning,
    )


@router.get("/{order_id}", response_model=OrderOut)
async def get_order(
    order_id: int,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> Order:
    result = await session.execute(select(Order).where(Order.id == order_id))
    order = result.scalar_one_or_none()
    if order is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="заказ не найден")
    if not _can_view(current_user, order):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="нет доступа к этому заказу",
        )
    return order


@router.post("/{order_id}/delivery-photo", response_model=OrderOut)
async def upload_delivery_photo(
    order_id: int,
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> Order:
    """Фото коробки на рецепции — подтверждение доставки (бриф, курьерское
    приложение). Загрузить его вправе только курьер, НАЗНАЧЕННЫЙ на этот
    заказ — тот же принцип владения, что у `_can_view`, только уже без
    исключения для персонала: подтверждение доставки теряет смысл, если его
    может проставить кто угодно, а не тот, кто физически стоял у стойки.
    """
    result = await session.execute(select(Order).where(Order.id == order_id))
    order = result.scalar_one_or_none()
    if order is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="заказ не найден")
    if current_user.role.code != RoleCode.COURIER.value or order.courier_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="фото доставки может загрузить только назначенный на заказ курьер",
        )

    url = await store_image(file, "orders", str(order_id), "delivery")

    order.delivery_photo_url = url
    await session.commit()
    await session.refresh(order)
    return order


@router.patch("/{order_id}/status", response_model=OrderOut)
async def update_order_status(
    order_id: int,
    payload: OrderStatusUpdate,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
    notification_sender: NotificationSender | None = Depends(_notification_sender_dependency),
) -> Order:
    """Смена статуса заказа с ролевой проверкой перехода и записью в историю.

    Порядок проверок намеренный: сначала роль (незачем подсказывать
    посторонней роли, какие переходы вообще существуют), потом владение
    заказом для курьера, и только потом — сама допустимость перехода.
    """
    result = await session.execute(select(Order).where(Order.id == order_id))
    order = result.scalar_one_or_none()
    if order is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="заказ не найден")

    role = current_user.role.code
    target = payload.status

    if role not in _STATUS_ROLES.get(target, set()):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="недостаточно прав для этого перехода статуса",
        )

    # Курьер ограничен заказами, которые либо ещё никому не назначены
    # (принимает/отклоняет свободный заказ — назначение произойдёт ниже при
    # принятии), либо уже назначены ему самому — тот же принцип владения,
    # что и в `_can_view`: курьер не имеет доступа к заказам других курьеров.
    if role == RoleCode.COURIER.value and order.courier_id not in (None, current_user.id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="заказ назначен другому курьеру",
        )

    if target not in _ALLOWED_TRANSITIONS.get(order.status, set()):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"недопустимый переход статуса: {order.status.value} -> {target.value}",
        )

    session.add(
        OrderStatusLog(
            order_id=order.id,
            from_status=order.status,
            to_status=target,
            changed_by=current_user.id,
        )
    )
    if target == OrderStatus.ACCEPTED and role == RoleCode.COURIER.value and order.courier_id is None:
        # Курьер принимает свободный заказ — этим действием он и назначается
        # на него; отдельного эндпоинта назначения курьера в задаче нет.
        order.courier_id = current_user.id
    order.status = target

    await session.commit()
    await session.refresh(order)

    if notification_sender is not None:
        background_tasks.add_task(
            notify_order_status_changed,
            notification_sender,
            user_id=order.user_id,
            order_id=order.id,
            new_status=target,
        )

    return order
