from __future__ import annotations

import hashlib
import hmac
import secrets
from uuid import UUID

from .config import settings


def generate_start_code() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


def start_code_digest(*, booking_id: UUID, code: str) -> str:
    message = f"{booking_id}:{code}".encode()
    return hmac.new(settings.otp_pepper.encode(), message, hashlib.sha256).hexdigest()


def verify_start_code(*, booking_id: UUID, code: str, digest: str) -> bool:
    expected = start_code_digest(booking_id=booking_id, code=code)
    return hmac.compare_digest(expected, digest)
