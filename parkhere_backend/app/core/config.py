import os
import dotenv

dotenv.load_dotenv()


def _int_env(name: str, default: int) -> int:
    value = os.getenv(name)
    if value in (None, ""):
        return default
    return int(value)


class Settings:
    DATABASE_URL: str = os.getenv("DATABASE_URL")
    JWT_SECRET: str = os.getenv("JWT_SECRET")
    SECRET_KEY: str = os.getenv("SECRET_KEY")
    SMTP_HOST: str = os.getenv("SMTP_HOST")
    SMTP_PORT: int = _int_env("SMTP_PORT", 587)
    SMTP_USER: str = os.getenv("SMTP_USER")
    SMTP_PASSWORD: str = os.getenv("SMTP_PASSWORD")
    SMTP_FROM: str = os.getenv("SMTP_FROM")

    ACCESS_TOKEN_EXPIRE_MINUTES: int = _int_env("ACCESS_TOKEN_EXPIRE_MINUTES", 360)
    MFA_EXPIRATION_MINUTES: int = _int_env("MFA_EXPIRATION_MINUTES", 10)
    MFA_SECRET_KEY: str = os.getenv("MFA_SECRET_KEY")
    PAYMENT_PROVIDER: str = os.getenv("PAYMENT_PROVIDER", "mock")
    MERCADO_PAGO_ACCESS_TOKEN: str = os.getenv("MERCADO_PAGO_ACCESS_TOKEN")
    MERCADO_PAGO_PUBLIC_KEY: str = os.getenv("MERCADO_PAGO_PUBLIC_KEY")
    MERCADO_PAGO_WEBHOOK_SECRET: str = os.getenv("MERCADO_PAGO_WEBHOOK_SECRET")

settings = Settings()
