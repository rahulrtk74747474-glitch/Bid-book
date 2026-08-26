from __future__ import annotations

import asyncio
from typing import Any

from google.auth.transport.requests import Request
from google.oauth2 import id_token

from .config import settings


async def verify_google_token(token: str) -> dict[str, Any]:
    """Verify a Google OpenID Connect ID token for the configured Bid&Book client."""
    if not settings.google_oauth_client_id:
        raise RuntimeError("Google sign-in is not configured on this Bid&Book server")

    def _verify() -> dict[str, Any]:
        claims = id_token.verify_oauth2_token(
            token,
            Request(),
            audience=settings.google_oauth_client_id,
        )
        if not claims.get("sub"):
            raise ValueError("Google account identifier is missing")
        if not claims.get("email"):
            raise ValueError("Google account email is missing")
        if claims.get("email_verified") is not True:
            raise ValueError("Google account email is not verified")
        return claims

    return await asyncio.to_thread(_verify)
