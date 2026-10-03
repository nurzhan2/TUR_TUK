"""Защита SMS-входа: счётчик попыток ввода и IP запроса.

Revision ID: 9e2f6a1b3c5d
Revises: 8d1e5f0a2b4c
Create Date: 2026-10-03
"""

import sqlalchemy as sa
from alembic import op

revision = "9e2f6a1b3c5d"
down_revision = "8d1e5f0a2b4c"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "sms_verification_codes",
        sa.Column("attempts", sa.Integer(), nullable=False, server_default="0"),
    )
    op.add_column("sms_verification_codes", sa.Column("ip", sa.String(45), nullable=True))
    op.create_index("ix_sms_verification_codes_ip", "sms_verification_codes", ["ip"])


def downgrade() -> None:
    op.drop_index("ix_sms_verification_codes_ip", table_name="sms_verification_codes")
    op.drop_column("sms_verification_codes", "ip")
    op.drop_column("sms_verification_codes", "attempts")
