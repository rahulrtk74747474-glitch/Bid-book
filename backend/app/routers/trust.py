from __future__ import annotations

import secrets
from uuid import UUID

from fastapi import APIRouter, HTTPException
from sqlalchemy import func, or_, select

from ..deps import CurrentUser, Db
from ..models import AuditLog, Booking, BookingStatus, ProviderProfile
from ..notifications import notify_user
from ..payment_gateway import payment_gateway
from ..security import utcnow
from ..trust_models import (
    Dispute,
    DisputeStatus,
    IdentityVerification,
    Payment,
    PaymentStatus,
    PayoutStatus,
    ProviderPayout,
    Refund,
    RefundStatus,
    Review,
    RiskSignal,
    VerificationStatus,
)
from ..trust_schemas import (
    BookingTrustOut,
    DevelopmentDisputeResolution,
    DisputeCreate,
    DisputeOut,
    IdentityVerificationCreate,
    IdentityVerificationOut,
    PaymentOut,
    PayoutOut,
    RefundOut,
    ReviewCreate,
    ReviewOut,
    ReviewSummary,
    TrustOverview,
)

router = APIRouter(prefix="/trust", tags=["trust-payments"])


async def _provider_for_user(db: Db, user_id: UUID) -> ProviderProfile | None:
    result = await db.execute(select(ProviderProfile).where(ProviderProfile.user_id == user_id))
    return result.scalar_one_or_none()


async def _booking_parties(db: Db, booking_id: UUID) -> tuple[Booking, ProviderProfile]:
    booking = await db.get(Booking, booking_id)
    if booking is None:
        raise HTTPException(status_code=404, detail="Booking not found")
    provider = await db.get(ProviderProfile, booking.provider_id)
    if provider is None:
        raise HTTPException(status_code=409, detail="Booking provider is unavailable")
    return booking, provider


def _require_participant(booking: Booking, provider: ProviderProfile, user_id: UUID) -> None:
    if user_id not in {booking.customer_user_id, provider.user_id}:
        raise HTTPException(status_code=403, detail="Only booking participants can access this resource")


async def _payment_for_booking(db: Db, booking_id: UUID) -> Payment | None:
    result = await db.execute(select(Payment).where(Payment.booking_id == booking_id))
    return result.scalar_one_or_none()


async def _payout_for_payment(db: Db, payment_id: UUID) -> ProviderPayout | None:
    result = await db.execute(select(ProviderPayout).where(ProviderPayout.payment_id == payment_id))
    return result.scalar_one_or_none()


@router.get("/overview", response_model=TrustOverview)
async def trust_overview(db: Db, user: CurrentUser) -> TrustOverview:
    verification_result = await db.execute(
        select(IdentityVerification)
        .where(IdentityVerification.user_id == user.id)
        .order_by(IdentityVerification.created_at.desc())
        .limit(1)
    )
    latest = verification_result.scalar_one_or_none()
    payment_count = await db.execute(select(func.count(Payment.id)).where(Payment.customer_user_id == user.id))
    provider = await _provider_for_user(db, user.id)
    payout_count = 0
    if provider:
        payouts = await db.execute(select(func.count(ProviderPayout.id)).where(ProviderPayout.provider_id == provider.id))
        payout_count = int(payouts.scalar_one())
    disputes = await db.execute(
        select(func.count(Dispute.id)).where(
            or_(Dispute.opened_by_user_id == user.id, Dispute.against_user_id == user.id),
            Dispute.status.in_([DisputeStatus.open, DisputeStatus.under_review]),
        )
    )
    return TrustOverview(
        identity_verified=user.identity_verified,
        latest_verification=IdentityVerificationOut.model_validate(latest) if latest else None,
        payments_count=int(payment_count.scalar_one()),
        payouts_count=payout_count,
        open_disputes_count=int(disputes.scalar_one()),
    )


@router.post("/identity/verifications", response_model=IdentityVerificationOut, status_code=201)
async def start_identity_verification(
    payload: IdentityVerificationCreate,
    db: Db,
    user: CurrentUser,
) -> IdentityVerificationOut:
    pending = await db.execute(
        select(IdentityVerification).where(
            IdentityVerification.user_id == user.id,
            IdentityVerification.status == VerificationStatus.pending,
        )
    )
    existing = pending.scalars().first()
    if existing:
        return IdentityVerificationOut.model_validate(existing)
    verification = IdentityVerification(
        user_id=user.id,
        method=payload.method,
        status=VerificationStatus.pending,
        provider_name="external",
        provider_reference=f"verify_{secrets.token_urlsafe(18)}",
    )
    db.add(verification)
    await db.commit()
    await db.refresh(verification)
    return IdentityVerificationOut.model_validate(verification)


@router.get("/identity/verifications", response_model=list[IdentityVerificationOut])
async def my_identity_verifications(db: Db, user: CurrentUser) -> list[IdentityVerificationOut]:
    result = await db.execute(
        select(IdentityVerification)
        .where(IdentityVerification.user_id == user.id)
        .order_by(IdentityVerification.created_at.desc())
    )
    return [IdentityVerificationOut.model_validate(item) for item in result.scalars().all()]


@router.post("/identity/verifications/{verification_id}/simulate-verify", response_model=IdentityVerificationOut)
async def development_verify_identity(
    verification_id: UUID,
    db: Db,
    user: CurrentUser,
) -> IdentityVerificationOut:
    from ..config import settings

    if settings.environment == "production":
        raise HTTPException(status_code=404, detail="Not found")
    result = await db.execute(
        select(IdentityVerification)
        .where(IdentityVerification.id == verification_id, IdentityVerification.user_id == user.id)
        .with_for_update()
    )
    verification = result.scalar_one_or_none()
    if verification is None:
        raise HTTPException(status_code=404, detail="Verification not found")
    verification.status = VerificationStatus.verified
    verification.verified_at = utcnow()
    user.identity_verified = True
    db.add(AuditLog(actor_user_id=user.id, action="identity.dev_verified", entity_type="identity_verification", entity_id=str(verification.id)))
    await db.commit()
    await db.refresh(verification)
    return IdentityVerificationOut.model_validate(verification)


@router.post("/bookings/{booking_id}/payment", response_model=PaymentOut, status_code=201)
async def create_payment(booking_id: UUID, db: Db, user: CurrentUser) -> PaymentOut:
    booking_result = await db.execute(select(Booking).where(Booking.id == booking_id).with_for_update())
    booking = booking_result.scalar_one_or_none()
    if booking is None:
        raise HTTPException(status_code=404, detail="Booking not found")
    if booking.customer_user_id != user.id:
        raise HTTPException(status_code=403, detail="Only the booking customer can create payment")
    existing = await _payment_for_booking(db, booking.id)
    if existing:
        return PaymentOut.model_validate(existing)
    try:
        intent = await payment_gateway().create_intent(
            amount_paise=booking.agreed_amount_paise,
            currency="INR",
            booking_reference=str(booking.id),
        )
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    payment = Payment(
        booking_id=booking.id,
        customer_user_id=user.id,
        provider_id=booking.provider_id,
        amount_paise=booking.agreed_amount_paise,
        platform_fee_paise=0,
        currency="INR",
        gateway=intent.gateway,
        gateway_reference=intent.reference,
        status=PaymentStatus.created,
    )
    db.add(payment)
    await db.commit()
    await db.refresh(payment)
    return PaymentOut.model_validate(payment)


@router.get("/bookings/{booking_id}", response_model=BookingTrustOut)
async def booking_trust(booking_id: UUID, db: Db, user: CurrentUser) -> BookingTrustOut:
    booking, provider = await _booking_parties(db, booking_id)
    _require_participant(booking, provider, user.id)
    payment = await _payment_for_booking(db, booking.id)
    payout = await _payout_for_payment(db, payment.id) if payment else None
    open_disputes = await db.execute(
        select(func.count(Dispute.id)).where(
            Dispute.booking_id == booking.id,
            Dispute.status.in_([DisputeStatus.open, DisputeStatus.under_review]),
        )
    )
    is_customer = user.id == booking.customer_user_id
    is_provider = user.id == provider.user_id
    captured = payment is not None and payment.status in {
        PaymentStatus.captured,
        PaymentStatus.partially_refunded,
    }
    return BookingTrustOut(
        payment=PaymentOut.model_validate(payment) if payment else None,
        payout=PayoutOut.model_validate(payout) if payout else None,
        can_pay=is_customer and payment is None and booking.status == BookingStatus.confirmed,
        can_start=is_provider and captured and booking.status == BookingStatus.confirmed,
        can_complete=is_customer and captured and booking.status == BookingStatus.in_progress,
        can_review=booking.status == BookingStatus.completed,
        open_dispute_count=int(open_disputes.scalar_one()),
    )


@router.post("/payments/{payment_id}/simulate-capture", response_model=PaymentOut)
async def development_capture_payment(payment_id: UUID, db: Db, user: CurrentUser) -> PaymentOut:
    from ..config import settings

    if settings.environment == "production":
        raise HTTPException(status_code=404, detail="Not found")
    result = await db.execute(select(Payment).where(Payment.id == payment_id).with_for_update())
    payment = result.scalar_one_or_none()
    if payment is None:
        raise HTTPException(status_code=404, detail="Payment not found")
    if payment.customer_user_id != user.id:
        raise HTTPException(status_code=403, detail="Only the payment customer can capture development payment")
    if payment.status == PaymentStatus.captured:
        return PaymentOut.model_validate(payment)
    if payment.status != PaymentStatus.created:
        raise HTTPException(status_code=409, detail="Payment cannot be captured in its current state")
    payment.status = PaymentStatus.captured
    payment.captured_at = utcnow()
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
            body=f"Payment of ₹{payment.amount_paise / 100:.2f} was captured for a booking.",
            entity_type="booking",
            entity_id=str(payment.booking_id),
        )
    await db.commit()
    await db.refresh(payment)
    return PaymentOut.model_validate(payment)


@router.post("/bookings/{booking_id}/start", response_model=dict[str, str])
async def start_booking(booking_id: UUID, db: Db, user: CurrentUser) -> dict[str, str]:
    booking_result = await db.execute(select(Booking).where(Booking.id == booking_id).with_for_update())
    booking = booking_result.scalar_one_or_none()
    if booking is None:
        raise HTTPException(status_code=404, detail="Booking not found")
    provider = await db.get(ProviderProfile, booking.provider_id)
    if provider is None or provider.user_id != user.id:
        raise HTTPException(status_code=403, detail="Only the assigned provider can start this booking")
    payment = await _payment_for_booking(db, booking.id)
    if payment is None or payment.status not in {PaymentStatus.captured, PaymentStatus.partially_refunded}:
        raise HTTPException(status_code=409, detail="Captured payment is required before starting work")
    if booking.status != BookingStatus.confirmed:
        raise HTTPException(status_code=409, detail="Booking cannot be started in its current state")
    booking.status = BookingStatus.in_progress
    await notify_user(
        db,
        user_id=booking.customer_user_id,
        kind="job_started",
        title="Job started",
        body="Your provider marked the booking as in progress.",
        entity_type="booking",
        entity_id=str(booking.id),
    )
    await db.commit()
    return {"status": booking.status.value}


@router.post("/bookings/{booking_id}/complete", response_model=dict[str, str])
async def complete_booking(booking_id: UUID, db: Db, user: CurrentUser) -> dict[str, str]:
    booking_result = await db.execute(select(Booking).where(Booking.id == booking_id).with_for_update())
    booking = booking_result.scalar_one_or_none()
    if booking is None:
        raise HTTPException(status_code=404, detail="Booking not found")
    if booking.customer_user_id != user.id:
        raise HTTPException(status_code=403, detail="Only the customer can confirm completion")
    if booking.status != BookingStatus.in_progress:
        raise HTTPException(status_code=409, detail="Booking must be in progress before completion")
    payment = await _payment_for_booking(db, booking.id)
    if payment is None or payment.status not in {PaymentStatus.captured, PaymentStatus.partially_refunded}:
        raise HTTPException(status_code=409, detail="Captured payment is required before completion")
    payout = await _payout_for_payment(db, payment.id)
    booking.status = BookingStatus.completed
    if payout and payout.status == PayoutStatus.pending:
        payout.status = PayoutStatus.eligible
        payout.eligible_at = utcnow()
    provider = await db.get(ProviderProfile, booking.provider_id)
    if provider:
        await notify_user(
            db,
            user_id=provider.user_id,
            kind="job_completed",
            title="Booking completed",
            body="The customer confirmed completion. Eligible payout can now proceed unless held for review.",
            entity_type="booking",
            entity_id=str(booking.id),
        )
    await db.commit()
    return {"status": booking.status.value}


@router.get("/payments", response_model=list[PaymentOut])
async def my_payments(db: Db, user: CurrentUser) -> list[PaymentOut]:
    result = await db.execute(select(Payment).where(Payment.customer_user_id == user.id).order_by(Payment.created_at.desc()))
    return [PaymentOut.model_validate(item) for item in result.scalars().all()]


@router.get("/payouts", response_model=list[PayoutOut])
async def my_payouts(db: Db, user: CurrentUser) -> list[PayoutOut]:
    provider = await _provider_for_user(db, user.id)
    if provider is None:
        return []
    result = await db.execute(select(ProviderPayout).where(ProviderPayout.provider_id == provider.id).order_by(ProviderPayout.created_at.desc()))
    return [PayoutOut.model_validate(item) for item in result.scalars().all()]


@router.post("/bookings/{booking_id}/reviews", response_model=ReviewOut, status_code=201)
async def create_review(booking_id: UUID, payload: ReviewCreate, db: Db, user: CurrentUser) -> ReviewOut:
    booking, provider = await _booking_parties(db, booking_id)
    _require_participant(booking, provider, user.id)
    if booking.status != BookingStatus.completed:
        raise HTTPException(status_code=409, detail="Reviews are available only after completed bookings")
    if user.id == booking.customer_user_id:
        subject_user_id = provider.user_id
        subject_provider_id = provider.id
    else:
        subject_user_id = booking.customer_user_id
        subject_provider_id = None
    existing = await db.execute(
        select(Review).where(
            Review.booking_id == booking.id,
            Review.reviewer_user_id == user.id,
            Review.subject_user_id == subject_user_id,
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=409, detail="You already reviewed this booking participant")
    review = Review(
        booking_id=booking.id,
        reviewer_user_id=user.id,
        subject_user_id=subject_user_id,
        subject_provider_id=subject_provider_id,
        rating=payload.rating,
        comment=payload.comment,
    )
    db.add(review)
    await db.commit()
    await db.refresh(review)
    return ReviewOut.model_validate(review)


@router.get("/providers/{provider_id}/reviews", response_model=list[ReviewOut])
async def provider_reviews(provider_id: UUID, db: Db) -> list[ReviewOut]:
    result = await db.execute(
        select(Review).where(Review.subject_provider_id == provider_id).order_by(Review.created_at.desc()).limit(100)
    )
    return [ReviewOut.model_validate(item) for item in result.scalars().all()]


@router.get("/providers/{provider_id}/review-summary", response_model=ReviewSummary)
async def provider_review_summary(provider_id: UUID, db: Db) -> ReviewSummary:
    result = await db.execute(
        select(func.count(Review.id), func.avg(Review.rating)).where(Review.subject_provider_id == provider_id)
    )
    count, average = result.one()
    return ReviewSummary(count=int(count), average_rating=float(average) if average is not None else None)


@router.post("/bookings/{booking_id}/disputes", response_model=DisputeOut, status_code=201)
async def open_dispute(booking_id: UUID, payload: DisputeCreate, db: Db, user: CurrentUser) -> DisputeOut:
    booking, provider = await _booking_parties(db, booking_id)
    _require_participant(booking, provider, user.id)
    against_user_id = provider.user_id if user.id == booking.customer_user_id else booking.customer_user_id
    payment = await _payment_for_booking(db, booking.id)
    if payload.requested_refund_paise > 0:
        if payment is None or payment.status not in {
            PaymentStatus.captured,
            PaymentStatus.partially_refunded,
        }:
            raise HTTPException(status_code=409, detail="Refund requests require a captured payment")
        refundable = payment.amount_paise - payment.refunded_paise
        if payload.requested_refund_paise > refundable:
            raise HTTPException(status_code=422, detail="Requested refund exceeds refundable payment amount")
    dispute = Dispute(
        booking_id=booking.id,
        opened_by_user_id=user.id,
        against_user_id=against_user_id,
        category=payload.category,
        summary=payload.summary,
        requested_refund_paise=payload.requested_refund_paise,
        status=DisputeStatus.open,
    )
    db.add(dispute)
    await db.flush()
    db.add(
        RiskSignal(
            entity_type="booking",
            entity_id=str(booking.id),
            kind="dispute_opened",
            score=20,
            detail=f"dispute_id={dispute.id};category={payload.category}",
        )
    )
    if payment:
        payout = await _payout_for_payment(db, payment.id)
        if payout and payout.status not in {PayoutStatus.paid, PayoutStatus.cancelled}:
            payout.status = PayoutStatus.held
            payout.hold_reason = f"Open dispute {dispute.id}"
    await notify_user(
        db,
        user_id=against_user_id,
        kind="dispute_opened",
        title="Booking dispute opened",
        body="A booking participant opened a dispute. Any unpaid payout is held for review.",
        entity_type="dispute",
        entity_id=str(dispute.id),
    )
    await db.commit()
    await db.refresh(dispute)
    return DisputeOut.model_validate(dispute)


@router.get("/disputes", response_model=list[DisputeOut])
async def my_disputes(db: Db, user: CurrentUser) -> list[DisputeOut]:
    result = await db.execute(
        select(Dispute)
        .where(or_(Dispute.opened_by_user_id == user.id, Dispute.against_user_id == user.id))
        .order_by(Dispute.created_at.desc())
    )
    return [DisputeOut.model_validate(item) for item in result.scalars().all()]


@router.post("/disputes/{dispute_id}/simulate-resolve", response_model=RefundOut | DisputeOut)
async def development_resolve_dispute(
    dispute_id: UUID,
    payload: DevelopmentDisputeResolution,
    db: Db,
    user: CurrentUser,
) -> RefundOut | DisputeOut:
    from ..config import settings

    if settings.environment == "production":
        raise HTTPException(status_code=404, detail="Not found")
    result = await db.execute(select(Dispute).where(Dispute.id == dispute_id).with_for_update())
    dispute = result.scalar_one_or_none()
    if dispute is None:
        raise HTTPException(status_code=404, detail="Dispute not found")
    if user.id not in {dispute.opened_by_user_id, dispute.against_user_id}:
        raise HTTPException(status_code=403, detail="Only dispute participants can use development resolution")
    if dispute.status in {DisputeStatus.resolved, DisputeStatus.closed}:
        raise HTTPException(status_code=409, detail="Dispute is already resolved")
    payment = await _payment_for_booking(db, dispute.booking_id)
    payout = await _payout_for_payment(db, payment.id) if payment else None
    dispute.status = DisputeStatus.resolved
    dispute.resolution = payload.note
    dispute.resolved_at = utcnow()
    if payload.outcome == "release":
        booking = await db.get(Booking, dispute.booking_id)
        if payout:
            if booking and booking.status == BookingStatus.completed:
                payout.status = PayoutStatus.eligible
                payout.eligible_at = payout.eligible_at or utcnow()
            else:
                payout.status = PayoutStatus.pending
            payout.hold_reason = None
        await db.commit()
        await db.refresh(dispute)
        return DisputeOut.model_validate(dispute)
    if payment is None or payment.status not in {PaymentStatus.captured, PaymentStatus.partially_refunded}:
        raise HTTPException(status_code=409, detail="Captured payment is required for refund resolution")
    refundable = payment.amount_paise - payment.refunded_paise
    amount = payload.refund_paise or dispute.requested_refund_paise
    if amount <= 0 or amount > refundable:
        raise HTTPException(status_code=422, detail="Refund amount must be positive and within the refundable balance")
    try:
        gateway_reference = await payment_gateway().refund(
            payment_reference=payment.gateway_reference,
            amount_paise=amount,
        )
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    refund = Refund(
        payment_id=payment.id,
        dispute_id=dispute.id,
        amount_paise=amount,
        status=RefundStatus.completed,
        gateway_reference=gateway_reference,
        completed_at=utcnow(),
    )
    db.add(refund)
    payment.refunded_paise += amount
    payment.status = PaymentStatus.refunded if payment.refunded_paise == payment.amount_paise else PaymentStatus.partially_refunded
    if payout:
        payout.status = PayoutStatus.cancelled if payment.status == PaymentStatus.refunded else PayoutStatus.held
        payout.hold_reason = "Refund issued"
    await db.commit()
    await db.refresh(refund)
    return RefundOut.model_validate(refund)
