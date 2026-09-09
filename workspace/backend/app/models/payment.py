import enum

from sqlalchemy import Enum, ForeignKey, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.mixins import TimestampMixin


class PaymentMethod(str, enum.Enum):
    """Способы оплаты. Наличных здесь нет и не будет (бриф: «оплата только
    онлайн») — значение "cash" структурно отсутствует, а не отклоняется
    проверкой в коде."""

    BANK_CARD = "bank_card"
    SBP = "sbp"


class PaymentStatus(str, enum.Enum):
    """Статус конкретной попытки оплаты в ЮKassa (не путать с
    `Order.payment_status` — тот про заказ в целом, этот про одну транзакцию;
    заказ может пережить несколько попыток, например отменённую и успешную)."""

    PENDING = "pending"
    SUCCEEDED = "succeeded"
    CANCELED = "canceled"


class Payment(TimestampMixin, Base):
    __tablename__ = "payments"

    id: Mapped[int] = mapped_column(primary_key=True)
    order_id: Mapped[int] = mapped_column(ForeignKey("orders.id"), nullable=False, index=True)
    # Внешний id платежа в ЮKassa — по нему сверяется вебхук с нашей записью
    # и им же запрашивается подтверждение статуса через GET (см. app/core/yookassa.py).
    yookassa_payment_id: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    status: Mapped[PaymentStatus] = mapped_column(
        Enum(PaymentStatus, name="payment_status", values_callable=lambda e: [x.value for x in e]),
        nullable=False,
        server_default=PaymentStatus.PENDING.value,
    )
    # Nullable: при confirmation.type=redirect способ оплаты выбирается на
    # стороне ЮKassa (карта/СБП по настройкам магазина), а не в нашем запросе —
    # заполняется тем, что вернёт API после подтверждения оплаты.
    payment_method: Mapped[PaymentMethod | None] = mapped_column(
        Enum(PaymentMethod, name="payment_method_type", values_callable=lambda e: [x.value for x in e]),
        nullable=True,
    )
    amount: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)
    currency: Mapped[str] = mapped_column(String(3), nullable=False, server_default="RUB")
    confirmation_url: Mapped[str | None] = mapped_column(String(1024))
