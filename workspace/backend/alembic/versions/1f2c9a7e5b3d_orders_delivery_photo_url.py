"""orders delivery photo url

Revision ID: 1f2c9a7e5b3d
Revises: 987b9a409988
Create Date: 2026-08-20 15:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '1f2c9a7e5b3d'
down_revision: Union[str, None] = '987b9a409988'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('orders', sa.Column('delivery_photo_url', sa.String(length=1024), nullable=True))


def downgrade() -> None:
    op.drop_column('orders', 'delivery_photo_url')
