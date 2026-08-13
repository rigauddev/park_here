import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from app.core.config import settings


class EmailService:

    @staticmethod
    async def send_mfa_email(to_email: str, code: str):
        EmailService.send_email(
            to_email=to_email,
            subject="Seu código de verificação ParkHere",
            body=f"<h1>{code}</h1>",
        )

    @staticmethod
    def send_email(to_email: str, subject: str, body: str):
        msg = MIMEMultipart()
        msg["From"] = settings.SMTP_FROM
        msg["To"] = to_email
        msg["Subject"] = subject

        msg.attach(MIMEText(body, "html"))

        try:
            server = smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT)
            server.starttls()
            server.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
            server.sendmail(settings.SMTP_USER, to_email, msg.as_string())
            server.quit()
        except Exception as e:
            print(f"Erro ao enviar email: {e}")
