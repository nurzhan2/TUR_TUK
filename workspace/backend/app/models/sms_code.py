from datetime import datetime

from sqlalchemy import DateTime, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.mixins import TimestampMixin


class SmsVerificationCode(TimestampMixin, Base):
    __tablename__ = "sms_verification_codes"

    id: Mapped[int] = mapped_column(primary_key=True)
    phone: Mapped[str] = mapped_column(String(20), nullable=False, index=True)
    code: Mapped[str] = mapped_column(String(8), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    # NULL = ещё не использован. Раздельно от expires_at: код мог быть верно
    # введён до истечения TTL, а второй раз с тем же кодом пройти не должен.
    consumed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    # Неверные вводы: после лимита код сгорает — перебор 10^6 вариантов
    # превращается в 5 попыток на одну SMS.
    attempts: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0")
    # С какого IP запрошен код — для лимита отправок на адрес (SMS-pumping).
    ip: Mapped[str | None] = mapped_column(String(45), index=True)
