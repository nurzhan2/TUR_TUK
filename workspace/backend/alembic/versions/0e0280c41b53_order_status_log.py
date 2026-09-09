"""order status log

Revision ID: 0e0280c41b53
Revises: 53fad0634450
Create Date: 2026-08-30 01:43:37.106138

История смены статусов заказа (задача «Управление статусами заказа»).
Переиспользует уже существующий тип `order_status` (заведён миграцией
d7b9c64a5d10) — create_type=False, иначе CREATE TYPE упадёт на уже
существующем имени (тот же приём, что у самой колонки `orders.status`).

**Обязательно `postgresql.ENUM`, не generic `sa.Enum`.** Generic `sa.Enum(...,
create_type=False)` этот флаг для `op.create_table()` не соблюдает — DDL-
компилятор всё равно эмитит `CREATE TYPE order_status`, что падает
`DuplicateObjectError` на уже существующем имени (проверено живьём при
первой попытке применить эту миграцию). `postgresql.ENUM` — тот
диалект-специфичный тип, для которого `create_type` действительно
подавляет автосоздание.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = '0e0280c41b53'
down_revision: Union[str, None] = '53fad0634450'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


ORDER_STATUS = postgresql.ENUM(
    'created', 'accepted', 'assembling', 'delivering', 'delivered', 'cancelled',
    name='order_status',
    create_type=False,
)


def upgrade() -> None:
    op.create_table(
        'order_status_log',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('order_id', sa.Integer(), nullable=False),
        sa.Column('from_status', ORDER_STATUS, nullable=False),
        sa.Column('to_status', ORDER_STATUS, nullable=False),
        sa.Column('changed_by', sa.Integer(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['order_id'], ['orders.id'], ),
        sa.ForeignKeyConstraint(['changed_by'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(op.f('ix_order_status_log_order_id'), 'order_status_log', ['order_id'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_order_status_log_order_id'), table_name='order_status_log')
    op.drop_table('order_status_log')
