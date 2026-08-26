from __future__ import annotations

import hashlib
import hmac
import secrets
from datetime import UTC, datetime, timedelta
from uuid import UUID

import jwt
from pwdlib import PasswordHash

from .config import settings

_password_hash = PasswordHash.recommended()


def utcnow() -> datetime:
    return datetime.now(UTC)


def as_utc(value: datetime) -> datetime:
    """Return an aware UTC datetime even when a DB driver returns a naive value.

    PostgreSQL preserves timezone-aware values for DateTime(timezone=True), while
    SQLite commonly returns the same stored timestamp without tzinfo. Development
    and phone-test builds use SQLite, so normalize values before Python-side
    comparisons to keep auth/session expiry checks portable across both databases.
    """
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)


def normalize_indian_phone(raw: str) -> str:
    digits = "".join(ch for ch in raw if ch.isdigit())
    if len(digits) == 12 and digits.startswith("91"):
        digits = digits[2:]
    if len(digits) != 10 or digits[0] not in "6789":
        raise ValueError("Enter a valid Indian mobile number.")
    return f"+91{digits}"


def normalize_email(raw: str) -> str:
    email = raw.strip().lower()
    if len(email) > 320 or email.count("@") != 1:
        raise ValueError("Enter a valid email address.")
    local, domain = email.split("@", 1)
    if not local or not domain or "." not in domain or domain.startswith(".") or domain.endswith("."):
        raise ValueError("Enter a valid email address.")
    return email


def hash_password(password: str) -> str:
    return _password_hash.hash(password)


def verify_password(password: str, encoded: str) -> bool:
    try:
        return _password_hash.verify(password, encoded)
    except Exception:
        return False


def generate_otp() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


def otp_digest(*, challenge_id: UUID, phone: str, otp: str) -> str:
    message = f"{challenge_id}:{phone}:{otp}".encode()
    return hmac.new(settings.otp_pepper.encode(), message, hashlib.sha256).hexdigest()


def verify_otp_digest(*, challenge_id: UUID, phone: str, otp: str, digest: str) -> bool:
    candidate = otp_digest(challenge_id=challenge_id, phone=phone, otp=otp)
    return hmac.compare_digest(candidate, digest)


def new_refresh_token() -> str:
    return secrets.token_urlsafe(48)


def refresh_token_hash(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def create_access_token(*, user_id: UUID, session_id: UUID) -> str:
    now = utcnow()
    payload = {
        "sub": str(user_id),
        "sid": str(session_id),
        "typ": "access",
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=settings.access_token_minutes)).timestamp()),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256")


def decode_access_token(token: str) -> tuple[UUID, UUID]:
    payload = jwt.decode(token, settings.jwt_secret, algorithms=["HS256"])
    if payload.get("typ") != "access":
        raise jwt.InvalidTokenError("Wrong token type")
    return UUID(payload["sub"]), UUID(payload["sid"])
