"""payments and order payment status

Revision ID: 936cda328a8d
Revises: 0e0280c41b53
Create Date: 2026-08-30 19:00:00.000000

Задача «Интеграция ЮKassa». `orders.payment_status` — отдельная ось от уже
существующего `orders.status` (курьерский цикл): платёж переводит заказ
в "paid" независимо от того, принят ли он ещё курьером (см.
`app/models/order.py`, docstring `OrderPaymentStatus`). Таблица `payments`
хранит каждую попытку оплаты в ЮKassa отдельной строкой — заказ может
пережить отменённый платёж и повторную успешную попытку.

**Все три ENUM здесь — `create_type=False`, хотя типы НОВЫЕ.** Без этого
флага `op.add_column()`/`op.create_table()` сами эмитят `CREATE TYPE` при
компиляции DDL колонки — ВТОРОЙ РАЗ поверх explicit `.create(bind,
checkfirst=True)` ниже, и падают `DuplicateObjectError`. Проверено живьём:
без флага миграция падает на второй по счёту эмитируемой `CREATE TYPE`
именно так. `create_type=False` просто говорит SQLAlchemy «этим типом
владеет не колонка» — создание и удаление остаются полностью на explicit
`.create()`/`.drop()` вызовах в `upgrade()`/`downgrade()`.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = '936cda328a8d'
down_revision: Union[str, None] = '0e0280c41b53'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


ORDER_PAYMENT_STATUS = postgresql.ENUM(
    'unpaid', 'paid', 'failed',
    name='order_payment_status',
    create_type=False,
)
PAYMENT_STATUS = postgresql.ENUM(
    'pending', 'succeeded', 'canceled',
    name='payment_status',
    create_type=False,
)
PAYMENT_METHOD_TYPE = postgresql.ENUM(
    'bank_card', 'sbp',
    name='payment_method_type',
    create_type=False,
)


def upgrade() -> None:
    bind = op.get_bind()
    ORDER_PAYMENT_STATUS.create(bind, checkfirst=True)
    PAYMENT_STATUS.create(bind, checkfirst=True)
    PAYMENT_METHOD_TYPE.create(bind, checkfirst=True)

    op.add_column(
        'orders',
        sa.Column(
            'payment_status',
            ORDER_PAYMENT_STATUS,
            nullable=False,
            server_default='unpaid',
        ),
    )

    op.create_table(
        'payments',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('order_id', sa.Integer(), nullable=False),
        sa.Column('yookassa_payment_id', sa.String(length=64), nullable=False),
        sa.Column('status', PAYMENT_STATUS, nullable=False, server_default='pending'),
        sa.Column('payment_method', PAYMENT_METHOD_TYPE, nullable=True),
        sa.Column('amount', sa.Numeric(10, 2), nullable=False),
        sa.Column('currency', sa.String(length=3), nullable=False, server_default='RUB'),
        sa.Column('confirmation_url', sa.String(length=1024), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['order_id'], ['orders.id'], ),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('yookassa_payment_id'),
    )
    op.create_index(op.f('ix_payments_order_id'), 'payments', ['order_id'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_payments_order_id'), table_name='payments')
    op.drop_table('payments')
    op.drop_column('orders', 'payment_status')

    bind = op.get_bind()
    PAYMENT_METHOD_TYPE.drop(bind, checkfirst=True)
    PAYMENT_STATUS.drop(bind, checkfirst=True)
    ORDER_PAYMENT_STATUS.drop(bind, checkfirst=True)
