"""update user roles

Revision ID: 9e84ea8c5da9
Revises: 219c1bea445a
Create Date: 2026-03-06 17:11:45.033164

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '9e84ea8c5da9'
down_revision: Union[str, Sequence[str], None] = '219c1bea445a'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

def upgrade():
    op.execute("""
        ALTER TABLE users 
        MODIFY role ENUM(
            'CUSTOMER',
            'PARKING_ADMIN',
            'OPERATOR',
            'TOUR_GUIDE',
            'SUPER_ADMIN'
        ) NOT NULL
    """)

def downgrade():
    op.execute("""
        ALTER TABLE users 
        MODIFY role ENUM(
            'CUSTOMER'
        ) NOT NULL
    """)
