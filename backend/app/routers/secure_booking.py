from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, HTTPException
from sqlalchemy import select

from ..deps import CurrentUser, Db
from ..models import Booking, BookingStatus, ProviderProfile
from ..notifications import notify_user
from ..ops_models import BookingStartCode
from ..ops_schemas import StartCodeVerify
from ..security import utcnow
from ..start_code import verify_start_code
from ..trust_models import Payment, PaymentStatus

router = APIRouter(prefix="/ops/bookings", tags=["secure-booking"])


@router.post("/{booking_id}/start", response_model=dict[str, str])
async def start_booking_with_code(
    booking_id: UUID,
    payload: StartCodeVerify,
    db: Db,
    user: CurrentUser,
) -> dict[str, str]:
    booking_result = await db.execute(select(Booking).where(Booking.id == booking_id).with_for_update())
    booking = booking_result.scalar_one_or_none()
    if booking is None:
        raise HTTPException(status_code=404, detail="Booking not found")
    provider = await db.get(ProviderProfile, booking.provider_id)
    if provider is None or provider.user_id != user.id:
        raise HTTPException(status_code=403, detail="Only the assigned provider can start this booking")
    if booking.status != BookingStatus.confirmed:
        raise HTTPException(status_code=409, detail="Booking cannot be started in its current state")

    payment_result = await db.execute(select(Payment).where(Payment.booking_id == booking.id))
    payment = payment_result.scalar_one_or_none()
    if payment is None or payment.status not in {PaymentStatus.captured, PaymentStatus.partially_refunded}:
        raise HTTPException(status_code=409, detail="Captured payment is required before starting work")

    code_result = await db.execute(
        select(BookingStartCode).where(BookingStartCode.booking_id == booking.id).with_for_update()
    )
    record = code_result.scalar_one_or_none()
    if record is None or record.consumed_at is not None:
        raise HTTPException(status_code=409, detail="Customer start code is required")
    if record.expires_at <= utcnow():
        raise HTTPException(status_code=410, detail="Start code expired")
    if not verify_start_code(booking_id=booking.id, code=payload.code, digest=record.code_digest):
        raise HTTPException(status_code=401, detail="Incorrect start code")

    record.consumed_at = utcnow()
    booking.status = BookingStatus.in_progress
    await notify_user(
        db,
        user_id=booking.customer_user_id,
        kind="job_started",
        title="Job started",
        body="Your provider verified the start code and the booking is now in progress.",
        entity_type="booking",
        entity_id=str(booking.id),
    )
    await db.commit()
    return {"status": booking.status.value}
