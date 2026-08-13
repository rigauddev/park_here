"""tenant nullable for customer users

Revision ID: 3b36ea44e941
Revises: 9e84ea8c5da9
Create Date: 2026-03-06 17:52:55.868500

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '3b36ea44e941'
down_revision: Union[str, Sequence[str], None] = '9e84ea8c5da9'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade():
    op.alter_column(
        "users",
        "tenant_id",
        existing_type=sa.String(36),
        nullable=True
    )

def downgrade():
    op.alter_column(
        "users",
        "tenant_id",
        existing_type=sa.String(36),
        nullable=False
    )
