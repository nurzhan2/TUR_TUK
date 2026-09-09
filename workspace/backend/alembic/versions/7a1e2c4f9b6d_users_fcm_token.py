"""users fcm_token

Revision ID: 7a1e2c4f9b6d
Revises: 936cda328a8d
Create Date: 2026-08-30 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '7a1e2c4f9b6d'
down_revision: Union[str, None] = '936cda328a8d'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('users', sa.Column('fcm_token', sa.String(length=255), nullable=True))


def downgrade() -> None:
    op.drop_column('users', 'fcm_token')
