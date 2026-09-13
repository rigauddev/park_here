"""unit fee overrides, partner entitlements, email templates and admin audit

Revision ID: ff5a6b7c8d9e
Revises: fe4b5c6d7e8f
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

revision = "ff5a6b7c8d9e"
down_revision = "fe4b5c6d7e8f"
branch_labels = None
depends_on = None


def _email_templates_table():
    return sa.table(
        "email_templates",
        sa.column("id", sa.CHAR(36)),
        sa.column("template_key", sa.String(80)),
        sa.column("locale", sa.String(10)),
        sa.column("display_name", sa.String(120)),
        sa.column("subject", sa.String(255)),
        sa.column("header_html", sa.Text()),
        sa.column("body_html", sa.Text()),
        sa.column("footer_html", sa.Text()),
        sa.column("is_active", sa.Boolean()),
    )


def _has_table(name):
    return inspect(op.get_bind()).has_table(name)


def _has_column(table, column):
    return any(item["name"] == column for item in inspect(op.get_bind()).get_columns(table))


def _has_index(table, index):
    return any(item["name"] == index for item in inspect(op.get_bind()).get_indexes(table))


def upgrade():
    if not _has_column("tenants", "operator_limit_override"):
        op.add_column("tenants", sa.Column("operator_limit_override", sa.Integer(), nullable=True))
    if not _has_column("users", "deactivation_reason"):
        op.add_column("users", sa.Column("deactivation_reason", sa.Text(), nullable=True))

    if not _has_table("parking_platform_fees"):
        op.create_table(
        "parking_platform_fees",
        sa.Column("id", sa.CHAR(36), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("tenant_id", sa.String(36), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("parking_id", sa.String(36), sa.ForeignKey("parkings.id"), nullable=False),
        sa.Column("service_type", sa.String(50), nullable=False),
        sa.Column("fee_mode", sa.String(20), nullable=False, server_default="hybrid"),
        sa.Column("fixed_amount", sa.Float(), nullable=False, server_default="0"),
        sa.Column("percentage", sa.Float(), nullable=False, server_default="0"),
        sa.Column("min_fee", sa.Float(), nullable=False, server_default="0"),
        sa.Column("max_fee", sa.Float(), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.UniqueConstraint("parking_id", "service_type", name="uq_parking_fee_unit_service"),
        )
    if not _has_index("parking_platform_fees", "ix_parking_platform_fees_tenant_id"):
        op.create_index("ix_parking_platform_fees_tenant_id", "parking_platform_fees", ["tenant_id"])
    if not _has_index("parking_platform_fees", "ix_parking_platform_fees_parking_id"):
        op.create_index("ix_parking_platform_fees_parking_id", "parking_platform_fees", ["parking_id"])

    if not _has_table("partner_feature_entitlements"):
        op.create_table(
        "partner_feature_entitlements",
        sa.Column("id", sa.CHAR(36), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("tenant_id", sa.String(36), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("feature_key", sa.String(80), nullable=False),
        sa.Column("is_enabled", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("is_paid", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("price", sa.Float(), nullable=False, server_default="0"),
        sa.Column("billing_period", sa.String(20), nullable=False, server_default="monthly"),
        sa.Column("notes", sa.String(500), nullable=True),
        sa.UniqueConstraint("tenant_id", "feature_key", name="uq_partner_feature_tenant_key"),
        )
    if not _has_index("partner_feature_entitlements", "ix_partner_feature_entitlements_tenant_id"):
        op.create_index("ix_partner_feature_entitlements_tenant_id", "partner_feature_entitlements", ["tenant_id"])

    if not _has_table("email_templates"):
        op.create_table(
        "email_templates",
        sa.Column("id", sa.CHAR(36), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("template_key", sa.String(80), nullable=False),
        sa.Column("locale", sa.String(10), nullable=False, server_default="pt_BR"),
        sa.Column("display_name", sa.String(120), nullable=False),
        sa.Column("subject", sa.String(255), nullable=False),
        sa.Column("header_html", sa.Text(), nullable=False),
        sa.Column("body_html", sa.Text(), nullable=False),
        sa.Column("footer_html", sa.Text(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.UniqueConstraint("template_key", "locale", name="uq_email_template_key_locale"),
        )

    if not _has_table("admin_audit_logs"):
        op.create_table(
        "admin_audit_logs",
        sa.Column("id", sa.CHAR(36), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("actor_id", sa.String(36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("tenant_id", sa.String(36), sa.ForeignKey("tenants.id"), nullable=True),
        sa.Column("action", sa.String(80), nullable=False),
        sa.Column("target_type", sa.String(80), nullable=False),
        sa.Column("target_id", sa.String(36), nullable=False),
        sa.Column("details", sa.Text(), nullable=True),
        )
    for index, column in (
        ("ix_admin_audit_logs_actor_id", "actor_id"),
        ("ix_admin_audit_logs_tenant_id", "tenant_id"),
        ("ix_admin_audit_logs_action", "action"),
        ("ix_admin_audit_logs_target_id", "target_id"),
    ):
        if not _has_index("admin_audit_logs", index):
            op.create_index(index, "admin_audit_logs", [column])

    rows = []
    configs = {
        "welcome": (
            ("Boas-vindas", "Bem-vindo ao ParkHere", "Olá, {{name}}!", "Sua conta está pronta para usar o ParkHere."),
            ("Welcome", "Welcome to Park Here", "Hello, {{name}}!", "Your account is ready to use Park Here."),
        ),
        "mfa_code": (
            ("Código MFA", "Seu código de verificação ParkHere", "Olá, {{name}}", "Seu código de verificação é <strong>{{code}}</strong>. Ele expira em 10 minutos."),
            ("MFA code", "Your Park Here verification code", "Hello, {{name}}", "Your verification code is <strong>{{code}}</strong>. It expires in 10 minutes."),
        ),
        "user_deactivation": (
            ("Desativação de usuário", "Atualização sobre sua conta ParkHere", "Olá, {{name}}", "O acesso à sua conta foi desativado. Motivo: {{reason}}"),
            ("User deactivation", "An update about your Park Here account", "Hello, {{name}}", "Access to your account has been deactivated. Reason: {{reason}}"),
        ),
        "partner_deactivation": (
            ("Desativação de parceiro", "Atualização sobre sua empresa no ParkHere", "Olá, {{name}}", "O acesso da empresa {{company}} foi desativado. Motivo: {{reason}}"),
            ("Partner deactivation", "An update about your Park Here business", "Hello, {{name}}", "Access for {{company}} has been deactivated. Reason: {{reason}}"),
        ),
    }
    header = (
        '<div style="background:#07194f;padding:28px 32px;color:#fff;'
        'font-family:Arial,sans-serif"><img src="cid:parkhere-logo" alt="ParkHere" '
        'style="display:block;width:210px;max-width:100%;height:auto;margin-bottom:12px">'
        '<div style="font-size:14px;color:#dbeafe">{{slogan}}</div></div>'
    )
    footer = (
        '<div style="border-top:1px solid #e5e7eb;margin-top:28px;padding-top:16px;'
        'font:12px Arial,sans-serif;color:#64748b">{{company_footer}}<br>'
        'Rigaud Tech · ParkHere</div>'
    )
    for key, pairs in configs.items():
        for locale, values in zip(("pt_BR", "en"), pairs):
            display_name, subject, title, body = values
            rows.append({
                "id": f"00000000-0000-4000-8000-{len(rows)+1:012d}",
                "template_key": key,
                "locale": locale,
                "display_name": display_name,
                "subject": subject,
                "header_html": header,
                "body_html": (
                    '<div style="padding:28px 32px;font:15px/1.6 Arial,sans-serif;'
                    'color:#172554"><h1 style="font-size:22px">'
                    f'{title}</h1><p>{body}</p></div>'
                ),
                "footer_html": footer,
                "is_active": True,
            })
    if not inspect(op.get_bind()).has_table("email_templates") or not op.get_bind().execute(
        sa.text("SELECT 1 FROM email_templates LIMIT 1")
    ).first():
        op.bulk_insert(_email_templates_table(), rows)


def downgrade():
    op.drop_table("admin_audit_logs")
    op.drop_table("email_templates")
    op.drop_table("partner_feature_entitlements")
    op.drop_table("parking_platform_fees")
    op.drop_column("users", "deactivation_reason")
    op.drop_column("tenants", "operator_limit_override")
