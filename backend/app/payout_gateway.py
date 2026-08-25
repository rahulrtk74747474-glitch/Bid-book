from __future__ import annotations

import secrets
from typing import Protocol

import httpx

from .config import settings


class PayoutGateway(Protocol):
    async def send(self, *, provider_reference: str, amount_paise: int, currency: str) -> str: ...


class DevelopmentPayoutGateway:
    async def send(self, *, provider_reference: str, amount_paise: int, currency: str) -> str:
        del provider_reference, amount_paise, currency
        return f"devpayout_{secrets.token_urlsafe(18)}"


class HttpPayoutGateway:
    async def send(self, *, provider_reference: str, amount_paise: int, currency: str) -> str:
        try:
            async with httpx.AsyncClient(timeout=20) as client:
                response = await client.post(
                    settings.payout_http_url,
                    headers={
                        "Authorization": f"Bearer {settings.payout_http_token}",
                        "Idempotency-Key": f"bidbook:{provider_reference}:{amount_paise}:{currency}",
                    },
                    json={
                        "provider_reference": provider_reference,
                        "amount_paise": amount_paise,
                        "currency": currency,
                        "source": "bidbook",
                    },
                )
                response.raise_for_status()
                body = response.json()
        except (httpx.HTTPError, ValueError) as exc:
            raise RuntimeError("Payout provider request failed") from exc
        reference = body.get("reference") if isinstance(body, dict) else None
        if not isinstance(reference, str) or not reference:
            raise RuntimeError("Payout provider returned an invalid reference")
        return reference


class UnconfiguredProductionPayoutGateway:
    async def send(self, *, provider_reference: str, amount_paise: int, currency: str) -> str:
        del provider_reference, amount_paise, currency
        raise RuntimeError("Production payout gateway adapter is not configured")


def payout_gateway() -> PayoutGateway:
    if settings.environment in {"development", "test"} and not settings.payout_http_url:
        return DevelopmentPayoutGateway()
    if settings.payout_http_url and settings.payout_http_token:
        return HttpPayoutGateway()
    return UnconfiguredProductionPayoutGateway()
