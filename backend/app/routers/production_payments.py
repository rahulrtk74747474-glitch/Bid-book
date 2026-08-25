from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, HTTPException
from sqlalchemy import select

from ..config import settings
from ..deps import CurrentUser, Db
from ..models import Booking, BookingStatus
from ..payment_gateway import payment_gateway
from ..trust_models import Payment, PaymentStatus
from ..trust_schemas import PaymentOut

router = APIRouter(prefix="/production", tags=["production-payments"])


@router.post("/bookings/{booking_id}/payment", response_model=PaymentOut, status_code=201)
async def create_production_payment(
    booking_id: UUID,
    db: Db,
    user: CurrentUser,
) -> PaymentOut:
    booking_result = await db.execute(
        select(Booking).where(Booking.id == booking_id).with_for_update()
    )
    booking = booking_result.scalar_one_or_none()
    if booking is None:
        raise HTTPException(status_code=404, detail="Booking not found")
    if booking.customer_user_id != user.id:
        raise HTTPException(status_code=403, detail="Only the booking customer can create payment")
    if booking.status != BookingStatus.confirmed:
        raise HTTPException(status_code=409, detail="This booking is not awaiting payment")

    existing_result = await db.execute(select(Payment).where(Payment.booking_id == booking.id))
    existing = existing_result.scalar_one_or_none()
    if existing:
        return PaymentOut.model_validate(existing)

    platform_fee = min(
        booking.agreed_amount_paise,
        (booking.agreed_amount_paise * settings.platform_fee_bps + 9999) // 10000,
    )
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
        platform_fee_paise=platform_fee,
        currency="INR",
        gateway=intent.gateway,
        gateway_reference=intent.reference,
        status=PaymentStatus.created,
    )
    db.add(payment)
    await db.commit()
    await db.refresh(payment)
    return PaymentOut.model_validate(payment)
