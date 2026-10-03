import enum

from sqlalchemy import Enum, ForeignKey, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.mixins import TimestampMixin
from app.models.order_item import OrderItem


class OrderStatus(str, enum.Enum):
    """Статусы курьерского приложения (см. бриф) + created/cancelled по краям цикла."""

    CREATED = "created"
    ACCEPTED = "accepted"
    ASSEMBLING = "assembling"
    DELIVERING = "delivering"
    DELIVERED = "delivered"
    CANCELLED = "cancelled"


class OrderPaymentStatus(str, enum.Enum):
    """Оплачен ли заказ — ОТДЕЛЬНАЯ ось от `OrderStatus`.

    `OrderStatus` — курьерский цикл (принят/собран/доставлен) с ролевым графом
    переходов в `app/api/orders.py`; смешивать туда "paid" значило бы городить
    два разных состояния (кто везёт коробку и заплатил ли клиент) в одну
    колонку. Источник правды по оплате — вебхук ЮKassa (`app/api/payments.py`),
    который трогает только это поле и не лезет в курьерский граф."""

    UNPAID = "unpaid"
    PAID = "paid"
    FAILED = "failed"


class Order(TimestampMixin, Base):
    __tablename__ = "orders"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    status: Mapped[OrderStatus] = mapped_column(
        # create_type=False: типом владеет миграция (d7b9c64a5d10), а не
        # модель. Без этого SQLAlchemy при первом же create_all() (например,
        # в тестовой обвязке) попытается завести тип заново и столкнётся
        # с уже существующим — CREATE TYPE не идемпотентен в PostgreSQL.
        Enum(OrderStatus, name="order_status", create_type=False,
             values_callable=lambda enum_cls: [e.value for e in enum_cls]),
        nullable=False,
        server_default=OrderStatus.CREATED.value,
    )
    total: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)
    # Разбивка итога для чека и админки: total = subtotal − discount + delivery_fee.
    subtotal: Mapped[float | None] = mapped_column(Numeric(10, 2))
    discount: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False, server_default="0")
    delivery_fee: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False, server_default="0")
    # Выбор гостя на чекауте: card | sbp. Передаётся в ЮKassa при оплате.
    payment_method: Mapped[str | None] = mapped_column(String(16))
    payment_status: Mapped[OrderPaymentStatus] = mapped_column(
        Enum(OrderPaymentStatus, name="order_payment_status", create_type=False,
             values_callable=lambda enum_cls: [e.value for e in enum_cls]),
        nullable=False,
        server_default=OrderPaymentStatus.UNPAID.value,
    )
    promo_id: Mapped[int | None] = mapped_column(ForeignKey("promo_codes.id"))
    hotel_name: Mapped[str] = mapped_column(String(255), nullable=False)
    room_number: Mapped[str] = mapped_column(String(50), nullable=False)
    # Не в списке задачи буквально, но без исполнителя заказа курьерский цикл
    # (принять/собрать/доставить) нечем привязать к конкретному курьеру.
    courier_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"))
    # Фото коробки на рецепции как подтверждение доставки (бриф, курьерское
    # приложение). Nullable — заполняется только курьером на шаге доставки.
    delivery_photo_url: Mapped[str | None] = mapped_column(String(1024))

    # История заказов и повтор заказа (бриф, deliverable) читают состав заказа
    # через эту связь; order_by держит позиции в порядке добавления, а не в
    # порядке, в котором их вернёт БД без сортировки.
    items: Mapped[list["OrderItem"]] = relationship(order_by="OrderItem.id")
