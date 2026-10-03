"""Заказ: «если товара нет», комментарий гостя, оценка после доставки.

Revision ID: a3c7e9f1d2b4
Revises: 9e2f6a1b3c5d
Create Date: 2026-10-03
"""

import sqlalchemy as sa
from alembic import op

revision = "a3c7e9f1d2b4"
down_revision = "9e2f6a1b3c5d"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("orders", sa.Column("if_missing", sa.String(16), nullable=False, server_default="replace"))
    op.add_column("orders", sa.Column("comment", sa.String(500), nullable=True))
    op.add_column("orders", sa.Column("rating", sa.Integer(), nullable=True))
    op.add_column("orders", sa.Column("rating_comment", sa.String(1000), nullable=True))


def downgrade() -> None:
    for column in ("rating_comment", "rating", "comment", "if_missing"):
        op.drop_column("orders", column)
