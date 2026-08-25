from __future__ import annotations

import secrets
from dataclasses import dataclass
from typing import Protocol

import httpx

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


class RazorpayGateway:
    base_url = "https://api.razorpay.com/v1"

    def _auth(self) -> tuple[str, str]:
        return settings.razorpay_key_id, settings.razorpay_key_secret

    async def create_intent(self, *, amount_paise: int, currency: str, booking_reference: str) -> GatewayIntent:
        try:
            async with httpx.AsyncClient(timeout=20, auth=self._auth()) as client:
                response = await client.post(
                    f"{self.base_url}/orders",
                    json={
                        "amount": amount_paise,
                        "currency": currency,
                        "receipt": booking_reference[:40],
                        "notes": {"booking_id": booking_reference, "source": "bidbook"},
                    },
                )
                response.raise_for_status()
                body = response.json()
        except (httpx.HTTPError, ValueError) as exc:
            raise RuntimeError("Payment gateway could not create an order") from exc
        reference = body.get("id") if isinstance(body, dict) else None
        if not isinstance(reference, str) or not reference.startswith("order_"):
            raise RuntimeError("Payment gateway returned an invalid order reference")
        return GatewayIntent(gateway="razorpay", reference=reference)

    async def refund(self, *, payment_reference: str, amount_paise: int) -> str:
        try:
            async with httpx.AsyncClient(timeout=20, auth=self._auth()) as client:
                payments = await client.get(f"{self.base_url}/orders/{payment_reference}/payments")
                payments.raise_for_status()
                body = payments.json()
                items = body.get("items", []) if isinstance(body, dict) else []
                captured = next(
                    (
                        item
                        for item in items
                        if isinstance(item, dict) and item.get("status") == "captured" and isinstance(item.get("id"), str)
                    ),
                    None,
                )
                if captured is None:
                    raise RuntimeError("No captured gateway payment is available to refund")
                refund = await client.post(
                    f"{self.base_url}/payments/{captured['id']}/refund",
                    json={"amount": amount_paise, "notes": {"source": "bidbook"}},
                )
                refund.raise_for_status()
                refund_body = refund.json()
        except RuntimeError:
            raise
        except (httpx.HTTPError, ValueError) as exc:
            raise RuntimeError("Payment gateway refund failed") from exc
        refund_id = refund_body.get("id") if isinstance(refund_body, dict) else None
        if not isinstance(refund_id, str):
            raise RuntimeError("Payment gateway returned an invalid refund reference")
        return refund_id


class UnconfiguredProductionGateway:
    async def create_intent(self, *, amount_paise: int, currency: str, booking_reference: str) -> GatewayIntent:
        del amount_paise, currency, booking_reference
        raise RuntimeError("Production payment gateway adapter is not configured")

    async def refund(self, *, payment_reference: str, amount_paise: int) -> str:
        del payment_reference, amount_paise
        raise RuntimeError("Production payment gateway adapter is not configured")


def payment_gateway() -> PaymentGateway:
    if settings.environment in {"development", "test"} and settings.payment_provider == "development":
        return DevelopmentPaymentGateway()
    if settings.payment_provider == "razorpay" and settings.razorpay_key_id and settings.razorpay_key_secret:
        return RazorpayGateway()
    return UnconfiguredProductionGateway()
