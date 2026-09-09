"""hotels lat/lon

Revision ID: 2b6f4d9a1c73
Revises: 7a1e2c4f9b6d
Create Date: 2026-08-31 00:00:00.000000

Координаты нужны для маршрутизации курьера (бриф: "координаты (lat/lon)
для маршрутизации курьера") — задача веб-админки "список отелей зоны
доставки". `Numeric(9, 6)` даёт точность ~11 см на экваторе, с запасом для
курьерской навигации, и хранит значение точно (в отличие от `Float`).
Nullable: у уже засеянных 345 отелей (миграция 6c9f1a3e7b21) координат нет,
проставлять их owner будет через саму эту CRUD-страницу или CSV-импортом.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "2b6f4d9a1c73"
down_revision: Union[str, None] = "7a1e2c4f9b6d"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("hotels", sa.Column("lat", sa.Numeric(9, 6), nullable=True))
    op.add_column("hotels", sa.Column("lon", sa.Numeric(9, 6), nullable=True))


def downgrade() -> None:
    op.drop_column("hotels", "lon")
    op.drop_column("hotels", "lat")
