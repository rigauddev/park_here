"""split system admin and partner manager roles

Revision ID: b9c0d1e2f3a4
Revises: a8b9c0d1e2f3
Create Date: 2026-08-14 16:45:00.000000

"""
from typing import Sequence, Union

from alembic import op


revision: str = "b9c0d1e2f3a4"
down_revision: Union[str, Sequence[str], None] = "a8b9c0d1e2f3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade():
    op.execute(
        """
        ALTER TABLE users
        MODIFY role ENUM(
            'CUSTOMER',
            'PARTNER_MANAGER',
            'PARKING_ADMIN',
            'OPERATOR',
            'TOUR_GUIDE',
            'SUPER_ADMIN'
        ) NOT NULL
        """
    )
    op.execute(
        """
        UPDATE users
        SET role = 'SUPER_ADMIN', tenant_id = NULL
        WHERE email = 'admin@parkhere.test'
        """
    )
    op.execute(
        """
        UPDATE users
        SET role = 'PARTNER_MANAGER'
        WHERE role = 'PARKING_ADMIN'
        """
    )


def downgrade():
    op.execute(
        """
        UPDATE users
        SET role = 'PARKING_ADMIN'
        WHERE role = 'PARTNER_MANAGER'
        """
    )
    op.execute(
        """
        ALTER TABLE users
        MODIFY role ENUM(
            'CUSTOMER',
            'PARKING_ADMIN',
            'OPERATOR',
            'TOUR_GUIDE',
            'SUPER_ADMIN'
        ) NOT NULL
        """
    )
