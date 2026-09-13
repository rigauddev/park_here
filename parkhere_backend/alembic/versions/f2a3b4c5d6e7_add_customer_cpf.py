"""store customer cpf"""
from alembic import op
import sqlalchemy as sa

revision = "f2a3b4c5d6e7"
down_revision = "f1a2b3c4d5e6"
branch_labels = None
depends_on = None

def upgrade():
    op.add_column("users", sa.Column("cpf", sa.String(length=14), nullable=True))
    op.create_unique_constraint("uq_users_cpf", "users", ["cpf"])

def downgrade():
    op.drop_constraint("uq_users_cpf", "users", type_="unique")
    op.drop_column("users", "cpf")
