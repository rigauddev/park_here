import os
import dotenv

dotenv.load_dotenv()

class Settings:
    DATABASE_URL: str = os.getenv("DATABASE_URL")
    JWT_SECRET: str = os.getenv("JWT_SECRET")
    SECRET_KEY: str = os.getenv("SECRET_KEY")
    SMTP_HOST: str = os.getenv("SMTP_HOST")
    SMTP_PORT: int = os.getenv("SMTP_PORT")
    SMTP_USER: str = os.getenv("SMTP_USER")
    SMTP_PASSWORD: str = os.getenv("SMTP_PASSWORD")
    SMTP_FROM: str = os.getenv("SMTP_FROM")

    MFA_EXPIRATION_MINUTES: int = os.getenv("MFA_EXPIRATION_MINUTES")
    MFA_SECRET_KEY: str = os.getenv("MFA_SECRET_KEY")
    PAYMENT_PROVIDER: str = os.getenv("PAYMENT_PROVIDER", "mercado_pago")
    MERCADO_PAGO_ACCESS_TOKEN: str = os.getenv("MERCADO_PAGO_ACCESS_TOKEN")
    MERCADO_PAGO_PUBLIC_KEY: str = os.getenv("MERCADO_PAGO_PUBLIC_KEY")
    MERCADO_PAGO_WEBHOOK_SECRET: str = os.getenv("MERCADO_PAGO_WEBHOOK_SECRET")

settings = Settings()
