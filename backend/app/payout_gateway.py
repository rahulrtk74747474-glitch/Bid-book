from __future__ import annotations

import secrets
from typing import Protocol

from .config import settings


class PayoutGateway(Protocol):
    async def send(self, *, provider_reference: str, amount_paise: int, currency: str) -> str: ...


class DevelopmentPayoutGateway:
    async def send(self, *, provider_reference: str, amount_paise: int, currency: str) -> str:
        del provider_reference, amount_paise, currency
        return f"devpayout_{secrets.token_urlsafe(18)}"


class UnconfiguredProductionPayoutGateway:
    async def send(self, *, provider_reference: str, amount_paise: int, currency: str) -> str:
        del provider_reference, amount_paise, currency
        raise RuntimeError("Production payout gateway adapter is not configured")


def payout_gateway() -> PayoutGateway:
    if settings.environment in {"development", "test"}:
        return DevelopmentPayoutGateway()
    return UnconfiguredProductionPayoutGateway()
