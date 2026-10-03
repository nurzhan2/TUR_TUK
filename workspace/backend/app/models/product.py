from sqlalchemy import Boolean, ForeignKey, Integer, Numeric, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.mixins import TimestampMixin


class Product(TimestampMixin, Base):
    __tablename__ = "products"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    price: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)
    # Старая цена для бейджа скидки «−25%»; показывается, только если больше price.
    old_price: Mapped[float | None] = mapped_column(Numeric(10, 2))
    # «шт», «250 г», «1 л» — подпись под ценой в карточке.
    unit: Mapped[str | None] = mapped_column(String(32))
    # Артикул владельца — по нему удобно сверять прайс и фото.
    sku: Mapped[str | None] = mapped_column(String(64))
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0")
    category_id: Mapped[int] = mapped_column(ForeignKey("categories.id"), nullable=False)
    is_available: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="true")
    photo_url: Mapped[str | None] = mapped_column(String(1024))
