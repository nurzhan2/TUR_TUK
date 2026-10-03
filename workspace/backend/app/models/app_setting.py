from datetime import datetime

from sqlalchemy import DateTime, Integer, func
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class AppSetting(Base):
    """Настройки сервиса, которые владелец меняет в админке.

    Одна строка (id=1) с JSON-документом: бренд, логотип, суммы доставки,
    способы оплаты, склад, контакты, баннеры. Структура документа и значения
    по умолчанию живут в `app/services/app_settings.py` — там же слияние с
    дефолтами, так что новое поле не требует миграции.
    """

    __tablename__ = "app_settings"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    data: Mapped[dict] = mapped_column(JSONB, nullable=False, server_default="{}")
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )
