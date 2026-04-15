import base64
import hashlib
from datetime import datetime, timedelta, timezone
from typing import Any

import bcrypt
from jose import jwt

from app.settings import settings


def _bcrypt_secret(password: str) -> bytes:
    # bcrypt has a 72-byte input limit; pre-hash long passwords deterministically.
    digest = hashlib.sha256(password.encode("utf-8")).digest()
    return base64.b64encode(digest)


def hash_password(password: str) -> str:
    secret = _bcrypt_secret(password)
    hashed = bcrypt.hashpw(secret, bcrypt.gensalt())
    return hashed.decode("utf-8")


def verify_password(password: str, password_hash: str) -> bool:
    secret = _bcrypt_secret(password)
    return bcrypt.checkpw(secret, password_hash.encode("utf-8"))


def _now() -> datetime:
    return datetime.now(timezone.utc)


def create_access_token(subject: str, extra: dict[str, Any]) -> str:
    expire = _now() + timedelta(minutes=settings.access_token_minutes)
    payload: dict[str, Any] = {"sub": subject, "exp": expire, "type": "access", **extra}
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def create_refresh_token(subject: str, extra: dict[str, Any]) -> str:
    expire = _now() + timedelta(days=settings.refresh_token_days)
    payload: dict[str, Any] = {"sub": subject, "exp": expire, "type": "refresh", **extra}
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def decode_token(token: str) -> dict[str, Any]:
    return jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])

