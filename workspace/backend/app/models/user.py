from datetime import date

from sqlalchemy import Date, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.mixins import TimestampMixin
from app.models.role import Role


class User(TimestampMixin, Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    phone: Mapped[str] = mapped_column(String(20), unique=True, nullable=False, index=True)
    name: Mapped[str | None] = mapped_column(String(255))
    dob: Mapped[date | None] = mapped_column(Date)
    hotel_name: Mapped[str | None] = mapped_column(String(255))
    room_number: Mapped[str | None] = mapped_column(String(50))
    role_id: Mapped[int] = mapped_column(ForeignKey("roles.id"), nullable=False)
    # Токен устройства для push-уведомлений (app/core/fcm.py). Nullable: клиент
    # ещё не прислал его (регистрация устройства — предмет отдельной задачи,
    # см. docs/DECISIONS.md), FcmSender на пустом токене просто не шлёт.
    fcm_token: Mapped[str | None] = mapped_column(String(255))

    role: Mapped["Role"] = relationship()
