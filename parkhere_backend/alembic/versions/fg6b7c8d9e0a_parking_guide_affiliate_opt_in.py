"""allow parking partners to opt in to guide referrals

Revision ID: fg6b7c8d9e0a
Revises: ff5a6b7c8d9e
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

revision = "fg6b7c8d9e0a"
down_revision = "ff5a6b7c8d9e"
branch_labels = None
depends_on = None


def upgrade():
    columns = {column["name"] for column in inspect(op.get_bind()).get_columns("parkings")}
    if "accepts_guide_affiliates" not in columns:
        op.add_column(
            "parkings",
            sa.Column(
                "accepts_guide_affiliates",
                sa.Boolean(),
                nullable=False,
                server_default=sa.false(),
            ),
        )
    # Preserve the prior, explicit decision to publish an offer to guides.
    op.execute(
        sa.text(
            "UPDATE parkings SET accepts_guide_affiliates = 1 "
            "WHERE guide_commission_terms IS NOT NULL "
            "AND guide_commission_terms <> ''"
        )
    )
    with op.batch_alter_table("parkings") as batch:
        batch.alter_column("accepts_guide_affiliates", server_default=None)


def downgrade():
    columns = {column["name"] for column in inspect(op.get_bind()).get_columns("parkings")}
    if "accepts_guide_affiliates" in columns:
        op.drop_column("parkings", "accepts_guide_affiliates")
