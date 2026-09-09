from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class ChatMessage(Base):
    """Чат клиент↔курьер по заказу и чат клиент↔оператор/бот поддержки.

    `order_id` пуст для сообщений в общий чат поддержки, не привязанных
    к конкретному заказу. `sender_id` пуст для сообщений чат-бота: бот не
    заведённый пользователь и не участвует в RBAC, а не роль из брифа.
    """

    __tablename__ = "chat_messages"

    id: Mapped[int] = mapped_column(primary_key=True)
    order_id: Mapped[int | None] = mapped_column(ForeignKey("orders.id"), index=True)
    sender_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"))
    body: Mapped[str] = mapped_column(Text, nullable=False)
    is_read: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="false")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    @property
    def is_bot(self) -> bool:
        return self.sender_id is None
