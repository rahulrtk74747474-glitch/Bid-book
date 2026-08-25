from __future__ import annotations

import base64
import hashlib
import hmac
import struct
import time
from datetime import timedelta
from uuid import UUID

import jwt

from .config import settings
from .security import utcnow


def _totp(secret: str, counter: int) -> str:
    try:
        key = base64.b32decode(secret.upper() + "=" * ((8 - len(secret) % 8) % 8), casefold=True)
    except Exception as exc:  # pragma: no cover - defensive configuration error
        raise RuntimeError("ADMIN_MFA_SECRET must be a valid base32 secret") from exc
    digest = hmac.new(key, struct.pack(">Q", counter), hashlib.sha1).digest()
    offset = digest[-1] & 0x0F
    value = struct.unpack(">I", digest[offset : offset + 4])[0] & 0x7FFFFFFF
    return f"{value % 1_000_000:06d}"


def verify_admin_totp(code: str) -> bool:
    if not settings.admin_mfa_secret or len(code) != 6 or not code.isdigit():
        return False
    counter = int(time.time()) // 30
    return any(
        hmac.compare_digest(_totp(settings.admin_mfa_secret, counter + drift), code)
        for drift in (-1, 0, 1)
    )


def create_admin_stepup_token(user_id: UUID) -> str:
    now = utcnow()
    payload = {
        "sub": str(user_id),
        "typ": "admin_stepup",
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=settings.admin_stepup_minutes)).timestamp()),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256")


def decode_admin_stepup_token(token: str) -> UUID:
    payload = jwt.decode(token, settings.jwt_secret, algorithms=["HS256"])
    if payload.get("typ") != "admin_stepup":
        raise jwt.InvalidTokenError("Wrong token type")
    return UUID(payload["sub"])
