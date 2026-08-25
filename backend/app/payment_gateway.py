from __future__ import annotations

import secrets
from dataclasses import dataclass
from typing import Protocol

from .config import settings


@dataclass(frozen=True)
class GatewayIntent:
    gateway: str
    reference: str


class PaymentGateway(Protocol):
    async def create_intent(self, *, amount_paise: int, currency: str, booking_reference: str) -> GatewayIntent: ...
    async def refund(self, *, payment_reference: str, amount_paise: int) -> str: ...


class DevelopmentPaymentGateway:
    async def create_intent(self, *, amount_paise: int, currency: str, booking_reference: str) -> GatewayIntent:
        del amount_paise, currency, booking_reference
        return GatewayIntent(gateway="development", reference=f"devpay_{secrets.token_urlsafe(18)}")

    async def refund(self, *, payment_reference: str, amount_paise: int) -> str:
        del payment_reference, amount_paise
        return f"devrefund_{secrets.token_urlsafe(18)}"


class UnconfiguredProductionGateway:
    async def create_intent(self, *, amount_paise: int, currency: str, booking_reference: str) -> GatewayIntent:
        del amount_paise, currency, booking_reference
        raise RuntimeError("Production payment gateway adapter is not configured")

    async def refund(self, *, payment_reference: str, amount_paise: int) -> str:
        del payment_reference, amount_paise
        raise RuntimeError("Production payment gateway adapter is not configured")


def payment_gateway() -> PaymentGateway:
    if settings.environment in {"development", "test"}:
        return DevelopmentPaymentGateway()
    return UnconfiguredProductionGateway()
