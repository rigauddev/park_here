from datetime import datetime, timedelta
from jose import jwt, JWTError
from passlib.context import CryptContext
from app.core.config import settings
import random
import hashlib

ALGORITHM = "HS256"

pwd_context = CryptContext(
    schemes=["bcrypt"],
    deprecated="auto",
)

def normalize_password(password: str) -> str:
    """
    bcrypt aceita no máximo 72 bytes.
    Fazemos hash SHA256 antes para evitar erro.
    """
    return hashlib.sha256(password.encode()).hexdigest()


def hash_password(password: str) -> str:
    normalized = normalize_password(password)
    return pwd_context.hash(normalized)


def verify_password(password: str, hashed: str) -> bool:
    normalized = normalize_password(password)
    return pwd_context.verify(normalized, hashed)

def create_access_token(data: dict, expires_delta: int | None = None):
    to_encode = data.copy()
    expire_minutes = expires_delta or settings.ACCESS_TOKEN_EXPIRE_MINUTES
    expire = datetime.utcnow() + timedelta(minutes=expire_minutes)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=ALGORITHM)

def create_refresh_token(data: dict):
    expire = datetime.utcnow() + timedelta(days=7)
    data.update({"exp": expire})
    return jwt.encode(data, settings.SECRET_KEY, algorithm=ALGORITHM)
