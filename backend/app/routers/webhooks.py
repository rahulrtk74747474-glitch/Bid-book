from __future__ import annotations

import hashlib
import hmac
import json
from datetime import datetime

from fastapi import APIRouter, HTTPException, Request
from sqlalchemy import select

from ..config import settings
from ..database import SessionFactory
from ..models import AuditLog, ProviderProfile, User
from ..notifications import notify_user
from ..production_models import WebhookReceipt
from ..production_schemas import ProviderWebhookAck
from ..security import utcnow
from ..trust_models import (
    IdentityVerification,
    Payment,
    PaymentStatus,
    PayoutStatus,
    ProviderPayout,
    VerificationStatus,
)

router = APIRouter(prefix="/webhooks", tags=["provider-webhooks"])


def _verify_hmac(raw: bytes, supplied: str | None, secret: str) -> None:
    if not secret or not supplied:
        raise HTTPException(status_code=401, detail="Webhook signature is missing")
    expected = hmac.new(secret.encode(), raw, hashlib.sha256).hexdigest()
    if not hmac.compare_digest(expected, supplied):
        raise HTTPException(status_code=401, detail="Webhook signature is invalid")


def _body(raw: bytes) -> dict:
    try:
        value = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=400, detail="Invalid webhook JSON") from exc
    if not isinstance(value, dict):
        raise HTTPException(status_code=400, detail="Invalid webhook payload")
    return value


async def _existing_receipt(db, provider: str, event_id: str) -> WebhookReceipt | None:
    result = await db.execute(
        select(WebhookReceipt).where(WebhookReceipt.provider == provider, WebhookReceipt.event_id == event_id)
    )
    return result.scalar_one_or_none()


@router.post("/razorpay", response_model=ProviderWebhookAck)
async def razorpay_webhook(request: Request) -> ProviderWebhookAck:
    raw = await request.body()
    _verify_hmac(raw, request.headers.get("x-razorpay-signature"), settings.razorpay_webhook_secret)
    body = _body(raw)
    event_type = str(body.get("event") or "unknown")
    event_id = request.headers.get("x-razorpay-event-id") or hashlib.sha256(raw).hexdigest()
    payload_hash = hashlib.sha256(raw).hexdigest()

    async with SessionFactory() as db:
        if await _existing_receipt(db, "razorpay", event_id):
            return ProviderWebhookAck(duplicate=True)
        receipt = WebhookReceipt(
            provider="razorpay",
            event_id=event_id,
            event_type=event_type,
            payload_sha256=payload_hash,
        )
        db.add(receipt)
        try:
            payment_entity = body.get("payload", {}).get("payment", {}).get("entity", {})
            if event_type in {"payment.captured", "payment.failed"} and isinstance(payment_entity, dict):
                order_id = payment_entity.get("order_id")
                amount = payment_entity.get("amount")
                if isinstance(order_id, str):
                    result = await db.execute(
                        select(Payment)
                        .where(Payment.gateway == "razorpay", Payment.gateway_reference == order_id)
                        .with_for_update()
                    )
                    payment = result.scalar_one_or_none()
                    if payment is not None:
                        if isinstance(amount, int) and amount != payment.amount_paise:
                            raise RuntimeError("Gateway amount does not match booking payment snapshot")
                        if event_type == "payment.captured":
                            payment.status = PaymentStatus.captured
                            payment.captured_at = payment.captured_at or utcnow()
                            payout_result = await db.execute(
                                select(ProviderPayout).where(ProviderPayout.payment_id == payment.id)
                            )
                            payout = payout_result.scalar_one_or_none()
                            if payout is None:
                                payout = ProviderPayout(
                                    payment_id=payment.id,
                                    provider_id=payment.provider_id,
                                    amount_paise=max(0, payment.amount_paise - payment.platform_fee_paise),
                                    status=PayoutStatus.pending,
                                )
                                db.add(payout)
                            provider = await db.get(ProviderProfile, payment.provider_id)
                            if provider:
                                await notify_user(
                                    db,
                                    user_id=provider.user_id,
                                    kind="payment_captured",
                                    title="Customer payment received",
                                    body=f"Payment of ₹{payment.amount_paise / 100:.2f} was confirmed.",
                                    entity_type="booking",
                                    entity_id=str(payment.booking_id),
                                )
                        elif payment.status == PaymentStatus.created:
                            payment.status = PaymentStatus.failed
            receipt.status = "processed"
            receipt.processed_at = utcnow()
            await db.commit()
        except Exception as exc:
            receipt.status = "failed"
            receipt.error = str(exc)[:1000]
            receipt.processed_at = utcnow()
            await db.commit()
            raise HTTPException(status_code=409, detail="Webhook event could not be applied safely") from exc
    return ProviderWebhookAck()


@router.post("/identity", response_model=ProviderWebhookAck)
async def identity_webhook(request: Request) -> ProviderWebhookAck:
    raw = await request.body()
    _verify_hmac(raw, request.headers.get("x-bidbook-signature"), settings.identity_webhook_secret)
    body = _body(raw)
    event_id = str(body.get("event_id") or hashlib.sha256(raw).hexdigest())
    reference = body.get("reference")
    status = body.get("status")
    if not isinstance(reference, str) or status not in {"verified", "rejected", "expired"}:
        raise HTTPException(status_code=422, detail="Invalid identity webhook payload")

    async with SessionFactory() as db:
        if await _existing_receipt(db, "identity", event_id):
            return ProviderWebhookAck(duplicate=True)
        receipt = WebhookReceipt(
            provider="identity",
            event_id=event_id,
            event_type=f"identity.{status}",
            payload_sha256=hashlib.sha256(raw).hexdigest(),
        )
        db.add(receipt)
        result = await db.execute(
            select(IdentityVerification)
            .where(IdentityVerification.provider_reference == reference)
            .with_for_update()
        )
        verification = result.scalar_one_or_none()
        if verification is None:
            receipt.status = "ignored"
            receipt.processed_at = utcnow()
            await db.commit()
            return ProviderWebhookAck()
        verification.status = VerificationStatus(status)
        verification.verified_at = utcnow() if status == "verified" else None
        user = await db.get(User, verification.user_id)
        if user:
            user.identity_verified = status == "verified"
            db.add(
                AuditLog(
                    actor_user_id=None,
                    action=f"identity.{status}",
                    entity_type="identity_verification",
                    entity_id=str(verification.id),
                    detail="provider_webhook",
                )
            )
        receipt.status = "processed"
        receipt.processed_at = utcnow()
        await db.commit()
    return ProviderWebhookAck()


@router.post("/payout", response_model=ProviderWebhookAck)
async def payout_webhook(request: Request) -> ProviderWebhookAck:
    raw = await request.body()
    _verify_hmac(raw, request.headers.get("x-bidbook-signature"), settings.payout_webhook_secret)
    body = _body(raw)
    event_id = str(body.get("event_id") or hashlib.sha256(raw).hexdigest())
    reference = body.get("reference")
    status = body.get("status")
    if not isinstance(reference, str) or status not in {"processing", "paid", "held", "failed"}:
        raise HTTPException(status_code=422, detail="Invalid payout webhook payload")

    async with SessionFactory() as db:
        if await _existing_receipt(db, "payout", event_id):
            return ProviderWebhookAck(duplicate=True)
        receipt = WebhookReceipt(
            provider="payout",
            event_id=event_id,
            event_type=f"payout.{status}",
            payload_sha256=hashlib.sha256(raw).hexdigest(),
        )
        db.add(receipt)
        result = await db.execute(
            select(ProviderPayout).where(ProviderPayout.gateway_reference == reference).with_for_update()
        )
        payout = result.scalar_one_or_none()
        if payout:
            if status == "paid":
                payout.status = PayoutStatus.paid
                payout.paid_at = utcnow()
            elif status == "processing":
                payout.status = PayoutStatus.processing
            else:
                payout.status = PayoutStatus.held
                payout.hold_reason = str(body.get("reason") or status)[:240]
        receipt.status = "processed" if payout else "ignored"
        receipt.processed_at = utcnow()
        await db.commit()
    return ProviderWebhookAck()
