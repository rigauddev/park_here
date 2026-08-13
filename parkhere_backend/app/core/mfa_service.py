from datetime import datetime, timedelta
from jose import jwt, JWTError
from passlib.context import CryptContext
from app.core.config import settings
import random
import hashlib


def generate_otp():
    return str(random.randint(100000, 999999))

def hash_otp(code: str):
    return hashlib.sha256(code.encode()).hexdigest()

def create_mfa_token(user_id: str, otp: str):
    expire = datetime.utcnow() + timedelta(
        minutes=int(settings.MFA_EXPIRATION_MINUTES)
    )

    payload = {
        "sub": user_id,
        "otp_hash": hash_otp(otp),
        "type": "mfa",
        "exp": expire
    }

    return jwt.encode(payload, settings.MFA_SECRET_KEY, algorithm="HS256")

def verify_mfa_token(token: str, code: str):
    try:
        payload = jwt.decode(
            token,
            settings.MFA_SECRET_KEY,
            algorithms=["HS256"]
        )

        if payload.get("type") != "mfa":
            return None

        if hash_otp(code) != payload.get("otp_hash"):
            return None

        return payload.get("sub")

    except JWTError:
        return None
    
def create_temp_login_token(user_id: str):
    expire = datetime.utcnow() + timedelta(minutes=5)

    payload = {
        "sub": user_id,
        "type": "mfa_init",
        "exp": expire
    }

    return jwt.encode(payload, settings.MFA_SECRET_KEY, algorithm="HS256")
