"""Админка как единый источник контента: настройки, поля товара/категории,
активность отелей, пароль персонала, разбивка суммы заказа.

Revision ID: 8d1e5f0a2b4c
Revises: 2b6f4d9a1c73
Create Date: 2026-10-03
"""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "8d1e5f0a2b4c"
down_revision = "2b6f4d9a1c73"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "app_settings",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("data", postgresql.JSONB(), nullable=False, server_default="{}"),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.execute("INSERT INTO app_settings (id, data) VALUES (1, '{}'::jsonb)")

    op.add_column("products", sa.Column("old_price", sa.Numeric(10, 2), nullable=True))
    op.add_column("products", sa.Column("unit", sa.String(32), nullable=True))
    op.add_column("products", sa.Column("sku", sa.String(64), nullable=True))
    op.add_column("products", sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"))

    op.add_column("categories", sa.Column("icon", sa.String(32), nullable=True))
    op.add_column("categories", sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"))

    op.add_column("hotels", sa.Column("is_active", sa.Boolean(), nullable=False, server_default="true"))

    op.add_column("promo_codes", sa.Column("title", sa.String(255), nullable=True))

    op.add_column("users", sa.Column("password_hash", sa.String(255), nullable=True))
    op.add_column("users", sa.Column("is_active", sa.Boolean(), nullable=False, server_default="true"))

    op.add_column("orders", sa.Column("subtotal", sa.Numeric(10, 2), nullable=True))
    op.add_column("orders", sa.Column("discount", sa.Numeric(10, 2), nullable=False, server_default="0"))
    op.add_column("orders", sa.Column("delivery_fee", sa.Numeric(10, 2), nullable=False, server_default="0"))
    op.add_column("orders", sa.Column("payment_method", sa.String(16), nullable=True))


def downgrade() -> None:
    for column in ("payment_method", "delivery_fee", "discount", "subtotal"):
        op.drop_column("orders", column)
    op.drop_column("users", "is_active")
    op.drop_column("users", "password_hash")
    op.drop_column("promo_codes", "title")
    op.drop_column("hotels", "is_active")
    op.drop_column("categories", "sort_order")
    op.drop_column("categories", "icon")
    for column in ("sort_order", "sku", "unit", "old_price"):
        op.drop_column("products", column)
    op.drop_table("app_settings")
