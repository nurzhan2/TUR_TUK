from decimal import Decimal

from sqlalchemy import Boolean, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.mixins import TimestampMixin


class Hotel(TimestampMixin, Base):
    """Список отелей/гостиниц Кемера — ограничивает зону доставки (см. бриф).

    `category`/`district`/`rating` существуют в БД с миграции
    `6c9f1a3e7b21` (seed 345 отелей), но не были объявлены здесь — известный
    и не раз задокументированный дрейф модели, см. docs/DECISIONS.md. Задача
    про CRUD-страницу отелей — первая, что реально читает и показывает эти
    поля в веб-админке, поэтому дрейф закрыт заодно: колонки уже есть в БД,
    новой миграции для них не нужно, а без ORM-полей список в `/admin/hotels`
    не смог бы показать ни звёздность, ни район ни одного из 345 отелей.

    `lat`/`lon` — новые колонки этой задачи (маршрутизация курьера, бриф).
    `Numeric`, не `Float`: широта/долгота — координаты, а не измерение,
    плавающая погрешность `float` в БД нежелательна для сверки на равенство
    в тестах."""

    __tablename__ = "hotels"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False, unique=True)
    address: Mapped[str | None] = mapped_column(String(500))
    category: Mapped[str | None] = mapped_column(String(10))
    district: Mapped[str | None] = mapped_column(String(100), index=True)
    rating: Mapped[Decimal | None] = mapped_column(Numeric(3, 1))
    lat: Mapped[Decimal | None] = mapped_column(Numeric(9, 6))
    lon: Mapped[Decimal | None] = mapped_column(Numeric(9, 6))
    # Выключенный отель пропадает из списка в приложении, но остаётся в БД —
    # старые заказы продолжают на него ссылаться по названию.
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="true")
