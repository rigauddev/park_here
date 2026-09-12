import html
import re
import smtplib
from email.mime.image import MIMEImage
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from pathlib import Path

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
class EmailService:
    @staticmethod
    async def send_mfa_email(
        to_email: str,
        code: str,
        db: AsyncSession | None = None,
        name: str = "",
        locale: str = "pt_BR",
    ):
        if db is not None:
            return await EmailService.send_template(
                db, to_email, "mfa_code", locale, {"name": name, "code": code}
            )
        EmailService.send_email(
            to_email=to_email,
            subject="Seu código de verificação ParkHere",
            body=f"<h1>{html.escape(code)}</h1>",
        )

    @staticmethod
    async def send_template(
        db: AsyncSession,
        to_email: str,
        template_key: str,
        locale: str = "pt_BR",
        values: dict[str, str] | None = None,
    ) -> bool:
        # Import lazily: app.core is imported while BaseModel is initializing,
        # so loading feature models at module import time creates a cycle.
        from app.modules.platform_fees.models import EmailTemplate

        locale = locale if locale in {"pt_BR", "en"} else "pt_BR"
        template = await db.scalar(
            select(EmailTemplate).where(
                EmailTemplate.template_key == template_key,
                EmailTemplate.locale == locale,
                EmailTemplate.is_active.is_(True),
            )
        )
        if template is None:
            print(f"Email template unavailable: {template_key}/{locale}")
            return False

        substitutions = {
            "slogan": (
                "Parking, mobility and services in one place"
                if locale == "en"
                else "Mobilidade, vagas e serviços em um só lugar"
            ),
            "company_footer": (
                "ParkHere · Rigaud Tech"
                if locale == "en"
                else "ParkHere · Rigaud Tech"
            ),
            **{key: html.escape(str(value)) for key, value in (values or {}).items()},
        }
        subject = _substitute(template.subject, substitutions)
        body = "".join(
            _substitute(fragment, substitutions)
            for fragment in (
                template.header_html,
                template.body_html,
                template.footer_html,
            )
        )
        return EmailService.send_email(to_email, subject, body, inline_logo=True)

    @staticmethod
    def send_email(
        to_email: str,
        subject: str,
        body: str,
        inline_logo: bool = False,
    ) -> bool:
        message = MIMEMultipart("related") if inline_logo else MIMEMultipart()
        message["From"] = settings.SMTP_FROM
        message["To"] = to_email
        message["Subject"] = subject

        if inline_logo:
            alternative = MIMEMultipart("alternative")
            alternative.attach(MIMEText(body, "html", "utf-8"))
            message.attach(alternative)
            logo_path = Path(__file__).parent / "email_assets" / "parkhere-logo.png"
            if logo_path.exists():
                image = MIMEImage(logo_path.read_bytes(), _subtype="png")
                image.add_header("Content-ID", "<parkhere-logo>")
                image.add_header("Content-Disposition", "inline", filename="parkhere-logo.png")
                message.attach(image)
        else:
            message.attach(MIMEText(body, "html", "utf-8"))

        try:
            with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT, timeout=10) as server:
                server.starttls()
                server.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
                server.sendmail(settings.SMTP_FROM, to_email, message.as_string())
            return True
        except Exception as error:
            # SMTP failures must not undo account/security changes. The admin
            # audit trail captures the action; deployment logs capture delivery.
            print(f"ParkHere email delivery failed: {type(error).__name__}")
            return False


def _substitute(template: str, values: dict[str, str]) -> str:
    return re.sub(
        r"\{\{([a-zA-Z0-9_]+)\}\}",
        lambda match: values.get(match.group(1), ""),
        template,
    )
