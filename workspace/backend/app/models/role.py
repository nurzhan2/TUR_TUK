import enum

from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class RoleCode(str, enum.Enum):
    """Roles from the brief (`_meta`, раздел 14) — seeded as rows in `roles`."""

    CLIENT = "client"
    COURIER = "courier"
    ADMIN = "admin"
    COLLECTOR = "collector"
    SUPPORT = "support"
    OWNER = "owner"
    DIRECTOR = "director"


class Role(Base):
    __tablename__ = "roles"

    id: Mapped[int] = mapped_column(primary_key=True)
    code: Mapped[str] = mapped_column(String(20), unique=True, nullable=False)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
