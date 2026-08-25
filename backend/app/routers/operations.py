from __future__ import annotations

from datetime import timedelta
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import delete, func, or_, select

from ..communication_models import PushDevice
from ..deps import CurrentAdmin, CurrentProvider, CurrentUser, Db
from ..models import AuditLog, Booking, BookingStatus, ProviderProfile, ServiceListing, ServiceRequest, Session, User
from ..notifications import notify_user
from ..ops_models import (
    BookingStartCode,
    CaseStatus,
    ContentReport,
    MediaAttachment,
    MediaStatus,
    ProviderAvailability,
    ReportStatus,
    SupportCase,
    SupportMessage,
    UserBlock,
    WarrantyClaim,
    WarrantyStatus,
)
from ..ops_schemas import (
    AdminDisputeDecision,
    AdminOverview,
    AdminPayoutDecision,
    AdminUserOut,
    AvailabilityOut,
    AvailabilityReplace,
    DiscoveryServiceOut,
    MediaIntentCreate,
    MediaIntentOut,
    MediaOut,
    ReportCreate,
    ReportDecision,
    ReportOut,
    RiskDecision,
    StartCodeOut,
    SupportCaseCreate,
    SupportCaseOut,
    SupportDecision,
    SupportMessageCreate,
    SupportMessageOut,
    SuspendUser,
    VerificationDecision,
    WarrantyCreate,
    WarrantyDecision,
    WarrantyOut,
)
from ..payment_gateway import payment_gateway
from ..payout_gateway import payout_gateway
from ..security import utcnow
from ..start_code import generate_start_code, start_code_digest
from ..storage import storage_adapter
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
    RiskSignalStatus,
    VerificationStatus,
)
from ..trust_schemas import DisputeOut, IdentityVerificationOut, PayoutOut

router = APIRouter()
ops = APIRouter(prefix="/ops", tags=["operations"])
admin = APIRouter(prefix="/admin", tags=["admin-operations"])

_ALLOWED_REPORT_ENTITIES = {
    "user",
    "provider",
    "service",
    "request",
    "booking",
    "group",
    "chat",
    "message",
    "review",
}
_ALLOWED_MEDIA_ENTITIES = {
    "profile",
    "provider",
    "service",
    "request",
    "booking",
    "dispute",
    "support",
    "warranty",
}
_ALLOWED_MEDIA_TYPES = {
    "image/jpeg",
    "image/png",
    "image/webp",
    "application/pdf",
}


async def _provider_for_user(db: Db, user_id: UUID) -> ProviderProfile | None:
    result = await db.execute(select(ProviderProfile).where(ProviderProfile.user_id == user_id))
    return result.scalar_one_or_none()


async def _payment_for_booking(db: Db, booking_id: UUID) -> Payment | None:
    result = await db.execute(select(Payment).where(Payment.booking_id == booking_id))
    return result.scalar_one_or_none()


async def _payout_for_payment(db: Db, payment_id: UUID) -> ProviderPayout | None:
    result = await db.execute(select(ProviderPayout).where(ProviderPayout.payment_id == payment_id))
    return result.scalar_one_or_none()


async def _can_attach(db: Db, *, user: User, entity_type: str, entity_id: str) -> bool:
    if entity_type == "profile":
        return entity_id == str(user.id)
    if entity_type == "provider":
        provider = await db.get(ProviderProfile, UUID(entity_id))
        return provider is not None and provider.user_id == user.id
    if entity_type == "service":
        listing = await db.get(ServiceListing, UUID(entity_id))
        if listing is None:
            return False
        provider = await db.get(ProviderProfile, listing.provider_id)
        return provider is not None and provider.user_id == user.id
    if entity_type == "request":
        request = await db.get(ServiceRequest, UUID(entity_id))
        return request is not None and request.created_by_user_id == user.id
    if entity_type == "booking":
        booking = await db.get(Booking, UUID(entity_id))
        if booking is None:
            return False
        provider = await db.get(ProviderProfile, booking.provider_id)
        return booking.customer_user_id == user.id or (provider is not None and provider.user_id == user.id)
    if entity_type == "dispute":
        dispute = await db.get(Dispute, UUID(entity_id))
        return dispute is not None and user.id in {dispute.opened_by_user_id, dispute.against_user_id}
    if entity_type == "support":
        case = await db.get(SupportCase, UUID(entity_id))
        return case is not None and case.user_id == user.id
    if entity_type == "warranty":
        claim = await db.get(WarrantyClaim, UUID(entity_id))
        if claim is None:
            return False
        provider = await db.get(ProviderProfile, claim.provider_id)
        return claim.customer_user_id == user.id or (provider is not None and provider.user_id == user.id)
    return False


@ops.post("/support/cases", response_model=SupportCaseOut, status_code=201)
async def create_support_case(payload: SupportCaseCreate, db: Db, user: CurrentUser) -> SupportCaseOut:
    case = SupportCase(user_id=user.id, **payload.model_dump())
    db.add(case)
    await db.flush()
    db.add(AuditLog(actor_user_id=user.id, action="support.case_created", entity_type="support_case", entity_id=str(case.id)))
    await db.commit()
    await db.refresh(case)
    return SupportCaseOut.model_validate(case)


@ops.get("/support/cases", response_model=list[SupportCaseOut])
async def my_support_cases(db: Db, user: CurrentUser) -> list[SupportCaseOut]:
    result = await db.execute(
        select(SupportCase).where(SupportCase.user_id == user.id).order_by(SupportCase.updated_at.desc())
    )
    return [SupportCaseOut.model_validate(item) for item in result.scalars().all()]


@ops.get("/support/cases/{case_id}/messages", response_model=list[SupportMessageOut])
async def support_messages(case_id: UUID, db: Db, user: CurrentUser) -> list[SupportMessageOut]:
    case = await db.get(SupportCase, case_id)
    if case is None or (case.user_id != user.id and not user.is_admin):
        raise HTTPException(status_code=404, detail="Support case not found")
    stmt = select(SupportMessage).where(SupportMessage.case_id == case.id)
    if not user.is_admin:
        stmt = stmt.where(SupportMessage.is_internal.is_(False))
    result = await db.execute(stmt.order_by(SupportMessage.created_at.asc()))
    return [SupportMessageOut.model_validate(item) for item in result.scalars().all()]


@ops.post("/support/cases/{case_id}/messages", response_model=SupportMessageOut, status_code=201)
async def add_support_message(
    case_id: UUID,
    payload: SupportMessageCreate,
    db: Db,
    user: CurrentUser,
) -> SupportMessageOut:
    case = await db.get(SupportCase, case_id)
    if case is None or (case.user_id != user.id and not user.is_admin):
        raise HTTPException(status_code=404, detail="Support case not found")
    if case.status == CaseStatus.closed:
        raise HTTPException(status_code=409, detail="This support case is closed")
    message = SupportMessage(case_id=case.id, author_user_id=user.id, body=payload.body.strip(), is_internal=False)
    db.add(message)
    case.updated_at = utcnow()
    await db.commit()
    await db.refresh(message)
    return SupportMessageOut.model_validate(message)


@ops.post("/reports", response_model=ReportOut, status_code=201)
async def create_report(payload: ReportCreate, db: Db, user: CurrentUser) -> ReportOut:
    if payload.entity_type not in _ALLOWED_REPORT_ENTITIES:
        raise HTTPException(status_code=422, detail="Unsupported report entity type")
    report = ContentReport(reporter_user_id=user.id, **payload.model_dump())
    db.add(report)
    await db.flush()
    db.add(AuditLog(actor_user_id=user.id, action="moderation.report_created", entity_type="content_report", entity_id=str(report.id)))
    await db.commit()
    await db.refresh(report)
    return ReportOut.model_validate(report)


@ops.get("/reports", response_model=list[ReportOut])
async def my_reports(db: Db, user: CurrentUser) -> list[ReportOut]:
    result = await db.execute(
        select(ContentReport)
        .where(ContentReport.reporter_user_id == user.id)
        .order_by(ContentReport.created_at.desc())
    )
    return [ReportOut.model_validate(item) for item in result.scalars().all()]


@ops.put("/blocks/{blocked_user_id}", status_code=204)
async def block_user(blocked_user_id: UUID, db: Db, user: CurrentUser) -> None:
    if blocked_user_id == user.id:
        raise HTTPException(status_code=409, detail="You cannot block yourself")
    target = await db.get(User, blocked_user_id)
    if target is None or not target.is_active:
        raise HTTPException(status_code=404, detail="User not found")
    result = await db.execute(
        select(UserBlock).where(
            UserBlock.blocker_user_id == user.id,
            UserBlock.blocked_user_id == blocked_user_id,
        )
    )
    if result.scalar_one_or_none() is None:
        db.add(UserBlock(blocker_user_id=user.id, blocked_user_id=blocked_user_id))
        await db.commit()


@ops.delete("/blocks/{blocked_user_id}", status_code=204)
async def unblock_user(blocked_user_id: UUID, db: Db, user: CurrentUser) -> None:
    await db.execute(
        delete(UserBlock).where(
            UserBlock.blocker_user_id == user.id,
            UserBlock.blocked_user_id == blocked_user_id,
        )
    )
    await db.commit()


@ops.get("/blocks", response_model=list[UUID])
async def blocked_users(db: Db, user: CurrentUser) -> list[UUID]:
    result = await db.execute(
        select(UserBlock.blocked_user_id).where(UserBlock.blocker_user_id == user.id)
    )
    return list(result.scalars().all())


@ops.get("/provider/availability", response_model=list[AvailabilityOut])
async def provider_availability(db: Db, provider: CurrentProvider) -> list[AvailabilityOut]:
    result = await db.execute(
        select(ProviderAvailability)
        .where(ProviderAvailability.provider_id == provider.id)
        .order_by(ProviderAvailability.weekday, ProviderAvailability.start_minute)
    )
    return [AvailabilityOut.model_validate(item) for item in result.scalars().all()]


@ops.put("/provider/availability", response_model=list[AvailabilityOut])
async def replace_provider_availability(
    payload: AvailabilityReplace,
    db: Db,
    provider: CurrentProvider,
) -> list[AvailabilityOut]:
    for slot in payload.slots:
        if slot.end_minute <= slot.start_minute:
            raise HTTPException(status_code=422, detail="Availability end must be after start")
    await db.execute(delete(ProviderAvailability).where(ProviderAvailability.provider_id == provider.id))
    created = [ProviderAvailability(provider_id=provider.id, **slot.model_dump()) for slot in payload.slots]
    db.add_all(created)
    await db.commit()
    for item in created:
        await db.refresh(item)
    return [AvailabilityOut.model_validate(item) for item in created]


@ops.post("/media/intents", response_model=MediaIntentOut, status_code=201)
async def create_media_intent(payload: MediaIntentCreate, db: Db, user: CurrentUser) -> MediaIntentOut:
    if payload.entity_type not in _ALLOWED_MEDIA_ENTITIES:
        raise HTTPException(status_code=422, detail="Unsupported media entity type")
    if payload.content_type not in _ALLOWED_MEDIA_TYPES:
        raise HTTPException(status_code=422, detail="Unsupported media type")
    try:
        authorized = await _can_attach(db, user=user, entity_type=payload.entity_type, entity_id=payload.entity_id)
    except ValueError:
        authorized = False
    if not authorized:
        raise HTTPException(status_code=403, detail="You cannot attach media to this resource")
    try:
        intent = await storage_adapter.create_upload_intent(user_id=str(user.id), content_type=payload.content_type)
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    media = MediaAttachment(
        owner_user_id=user.id,
        entity_type=payload.entity_type,
        entity_id=payload.entity_id,
        object_key=intent.object_key,
        content_type=payload.content_type,
        size_bytes=payload.size_bytes,
        public_url=intent.public_url,
    )
    db.add(media)
    await db.commit()
    await db.refresh(media)
    return MediaIntentOut(id=media.id, object_key=media.object_key, upload_url=intent.upload_url, public_url=media.public_url, status=media.status)


@ops.post("/media/{media_id}/complete", response_model=MediaOut)
async def complete_media(media_id: UUID, db: Db, user: CurrentUser) -> MediaOut:
    result = await db.execute(
        select(MediaAttachment)
        .where(MediaAttachment.id == media_id, MediaAttachment.owner_user_id == user.id)
        .with_for_update()
    )
    media = result.scalar_one_or_none()
    if media is None:
        raise HTTPException(status_code=404, detail="Media attachment not found")
    if media.status == MediaStatus.quarantined:
        raise HTTPException(status_code=409, detail="Media attachment is quarantined")
    media.status = MediaStatus.ready
    media.ready_at = utcnow()
    await db.commit()
    await db.refresh(media)
    return MediaOut.model_validate(media)


@ops.get("/media", response_model=list[MediaOut])
async def list_media(
    db: Db,
    user: CurrentUser,
    entity_type: str = Query(min_length=2, max_length=60),
    entity_id: str = Query(min_length=1, max_length=100),
) -> list[MediaOut]:
    try:
        authorized = await _can_attach(db, user=user, entity_type=entity_type, entity_id=entity_id)
    except ValueError:
        authorized = False
    if not authorized:
        raise HTTPException(status_code=403, detail="You cannot access media for this resource")
    result = await db.execute(
        select(MediaAttachment)
        .where(MediaAttachment.entity_type == entity_type, MediaAttachment.entity_id == entity_id, MediaAttachment.status != MediaStatus.deleted)
        .order_by(MediaAttachment.created_at.asc())
    )
    return [MediaOut.model_validate(item) for item in result.scalars().all()]


@ops.post("/bookings/{booking_id}/warranty-claims", response_model=WarrantyOut, status_code=201)
async def create_warranty_claim(booking_id: UUID, payload: WarrantyCreate, db: Db, user: CurrentUser) -> WarrantyOut:
    booking = await db.get(Booking, booking_id)
    if booking is None or booking.customer_user_id != user.id:
        raise HTTPException(status_code=404, detail="Booking not found")
    if booking.status != BookingStatus.completed:
        raise HTTPException(status_code=409, detail="Warranty claims require a completed booking")
    existing = await db.execute(
        select(WarrantyClaim).where(WarrantyClaim.booking_id == booking.id, WarrantyClaim.status.in_([WarrantyStatus.open, WarrantyStatus.under_review]))
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=409, detail="An open warranty claim already exists for this booking")
    claim = WarrantyClaim(booking_id=booking.id, customer_user_id=user.id, provider_id=booking.provider_id, issue=payload.issue.strip())
    db.add(claim)
    provider = await db.get(ProviderProfile, booking.provider_id)
    if provider:
        await notify_user(db, user_id=provider.user_id, kind="warranty_claim", title="Warranty claim opened", body="A customer opened a warranty claim for a completed booking.", entity_type="booking", entity_id=str(booking.id))
    await db.commit()
    await db.refresh(claim)
    return WarrantyOut.model_validate(claim)


@ops.get("/warranty-claims", response_model=list[WarrantyOut])
async def my_warranty_claims(db: Db, user: CurrentUser) -> list[WarrantyOut]:
    provider = await _provider_for_user(db, user.id)
    clauses = [WarrantyClaim.customer_user_id == user.id]
    if provider:
        clauses.append(WarrantyClaim.provider_id == provider.id)
    result = await db.execute(select(WarrantyClaim).where(or_(*clauses)).order_by(WarrantyClaim.created_at.desc()))
    return [WarrantyOut.model_validate(item) for item in result.scalars().all()]


@ops.post("/bookings/{booking_id}/start-code", response_model=StartCodeOut)
async def create_booking_start_code(booking_id: UUID, db: Db, user: CurrentUser) -> StartCodeOut:
    booking = await db.get(Booking, booking_id)
    if booking is None or booking.customer_user_id != user.id:
        raise HTTPException(status_code=404, detail="Booking not found")
    if booking.status != BookingStatus.confirmed:
        raise HTTPException(status_code=409, detail="Start code is available only for confirmed bookings")
    payment = await _payment_for_booking(db, booking.id)
    if payment is None or payment.status not in {PaymentStatus.captured, PaymentStatus.partially_refunded}:
        raise HTTPException(status_code=409, detail="Captured payment is required before creating a start code")
    code = generate_start_code()
    expires_at = utcnow() + timedelta(minutes=30)
    result = await db.execute(select(BookingStartCode).where(BookingStartCode.booking_id == booking.id).with_for_update())
    record = result.scalar_one_or_none()
    digest = start_code_digest(booking_id=booking.id, code=code)
    if record is None:
        record = BookingStartCode(booking_id=booking.id, code_digest=digest, expires_at=expires_at)
        db.add(record)
    else:
        record.code_digest = digest
        record.expires_at = expires_at
        record.consumed_at = None
        record.created_at = utcnow()
    await db.commit()
    return StartCodeOut(booking_id=booking.id, code=code, expires_at=expires_at)


@ops.get("/discovery/services", response_model=list[DiscoveryServiceOut])
async def discover_services(
    db: Db,
    user: CurrentUser,
    q: str | None = Query(default=None, max_length=120),
    category: str | None = Query(default=None, max_length=100),
    area: str | None = Query(default=None, max_length=180),
    min_price_paise: int | None = Query(default=None, ge=0),
    max_price_paise: int | None = Query(default=None, ge=0),
    verified_only: bool = False,
    weekday: int | None = Query(default=None, ge=0, le=6),
    sort: str = Query(default="newest", pattern="^(newest|price_low|price_high|rating)$"),
    limit: int = Query(default=50, ge=1, le=100),
) -> list[DiscoveryServiceOut]:
    rating_subquery = (
        select(Review.subject_provider_id.label("provider_id"), func.avg(Review.rating).label("rating"), func.count(Review.id).label("review_count"))
        .where(Review.subject_provider_id.is_not(None))
        .group_by(Review.subject_provider_id)
        .subquery()
    )
    blocked_subquery = select(UserBlock.blocked_user_id).where(UserBlock.blocker_user_id == user.id)
    stmt = (
        select(ServiceListing, ProviderProfile, User, rating_subquery.c.rating, rating_subquery.c.review_count)
        .join(ProviderProfile, ProviderProfile.id == ServiceListing.provider_id)
        .join(User, User.id == ProviderProfile.user_id)
        .outerjoin(rating_subquery, rating_subquery.c.provider_id == ProviderProfile.id)
        .where(ServiceListing.active.is_(True), ProviderProfile.active.is_(True), User.is_active.is_(True), User.suspended_at.is_(None), User.id.not_in(blocked_subquery))
    )
    if q:
        term = f"%{q.strip()}%"
        stmt = stmt.where(or_(ServiceListing.title.ilike(term), ServiceListing.description.ilike(term), ServiceListing.category.ilike(term), ProviderProfile.display_name.ilike(term)))
    if category:
        stmt = stmt.where(ServiceListing.category.ilike(f"%{category.strip()}%"))
    if area:
        stmt = stmt.where(ServiceListing.area.ilike(f"%{area.strip()}%"))
    if min_price_paise is not None:
        stmt = stmt.where(ServiceListing.price_paise >= min_price_paise)
    if max_price_paise is not None:
        stmt = stmt.where(ServiceListing.price_paise <= max_price_paise)
    if verified_only:
        stmt = stmt.where(User.identity_verified.is_(True))
    if weekday is not None:
        availability = select(ProviderAvailability.id).where(ProviderAvailability.provider_id == ProviderProfile.id, ProviderAvailability.weekday == weekday, ProviderAvailability.active.is_(True)).exists()
        stmt = stmt.where(availability)
    if sort == "price_low":
        stmt = stmt.order_by(ServiceListing.price_paise.asc(), ServiceListing.created_at.desc())
    elif sort == "price_high":
        stmt = stmt.order_by(ServiceListing.price_paise.desc(), ServiceListing.created_at.desc())
    elif sort == "rating":
        stmt = stmt.order_by(rating_subquery.c.rating.desc().nullslast(), ServiceListing.created_at.desc())
    else:
        stmt = stmt.order_by(ServiceListing.created_at.desc())
    rows = await db.execute(stmt.limit(limit))
    output: list[DiscoveryServiceOut] = []
    for listing, provider, provider_user, rating, review_count in rows.all():
        output.append(DiscoveryServiceOut(id=listing.id, provider_id=provider.id, provider_user_id=provider.user_id, provider_name=provider.display_name, provider_verified=provider_user.identity_verified, provider_rating=round(float(rating), 2) if rating is not None else None, provider_review_count=int(review_count or 0), title=listing.title, category=listing.category, description=listing.description, area=listing.area, price_paise=listing.price_paise, pricing_unit=listing.pricing_unit.value, created_at=listing.created_at))
    return output


@ops.post("/account/delete", status_code=204)
async def delete_account(db: Db, user: CurrentUser) -> None:
    now = utcnow()
    user.is_active = False
    user.deleted_at = now
    user.display_name = None
    user.identity_verified = False
    user.phone = f"deleted-{str(user.id)[:8]}"
    sessions = await db.execute(select(Session).where(Session.user_id == user.id, Session.revoked_at.is_(None)))
    for session in sessions.scalars().all():
        session.revoked_at = now
    devices = await db.execute(select(PushDevice).where(PushDevice.user_id == user.id, PushDevice.active.is_(True)))
    for device in devices.scalars().all():
        device.active = False
    db.add(AuditLog(actor_user_id=user.id, action="account.deleted", entity_type="user", entity_id=str(user.id)))
    await db.commit()


@admin.get("/overview", response_model=AdminOverview)
async def admin_overview(db: Db, _: CurrentAdmin) -> AdminOverview:
    async def count(stmt):
        result = await db.execute(stmt)
        return int(result.scalar_one() or 0)

    captured_statuses = [PaymentStatus.captured, PaymentStatus.partially_refunded, PaymentStatus.refunded]
    return AdminOverview(
        users=await count(select(func.count(User.id)).where(User.deleted_at.is_(None))),
        providers=await count(select(func.count(ProviderProfile.id)).where(ProviderProfile.active.is_(True))),
        active_services=await count(select(func.count(ServiceListing.id)).where(ServiceListing.active.is_(True))),
        bookings=await count(select(func.count(Booking.id))),
        completed_bookings=await count(select(func.count(Booking.id)).where(Booking.status == BookingStatus.completed)),
        captured_gmv_paise=await count(select(func.coalesce(func.sum(Payment.amount_paise), 0)).where(Payment.status.in_(captured_statuses))),
        platform_fees_paise=await count(select(func.coalesce(func.sum(Payment.platform_fee_paise), 0)).where(Payment.status.in_(captured_statuses))),
        open_disputes=await count(select(func.count(Dispute.id)).where(Dispute.status.in_([DisputeStatus.open, DisputeStatus.under_review]))),
        open_reports=await count(select(func.count(ContentReport.id)).where(ContentReport.status.in_([ReportStatus.open, ReportStatus.reviewing]))),
        open_support_cases=await count(select(func.count(SupportCase.id)).where(SupportCase.status.in_([CaseStatus.open, CaseStatus.in_progress]))),
        open_risk_signals=await count(select(func.count(RiskSignal.id)).where(RiskSignal.status == RiskSignalStatus.open)),
        pending_verifications=await count(select(func.count(IdentityVerification.id)).where(IdentityVerification.status == VerificationStatus.pending)),
        pending_payouts=await count(select(func.count(ProviderPayout.id)).where(ProviderPayout.status.in_([PayoutStatus.pending, PayoutStatus.eligible, PayoutStatus.held]))),
    )


@admin.get("/users", response_model=list[AdminUserOut])
async def admin_users(db: Db, _: CurrentAdmin, q: str | None = Query(default=None, max_length=120), suspended_only: bool = False, limit: int = Query(default=100, ge=1, le=200)) -> list[AdminUserOut]:
    stmt = select(User)
    if q:
        term = f"%{q.strip()}%"
        stmt = stmt.where(or_(User.phone.ilike(term), User.display_name.ilike(term)))
    if suspended_only:
        stmt = stmt.where(User.suspended_at.is_not(None))
    result = await db.execute(stmt.order_by(User.created_at.desc()).limit(limit))
    return [AdminUserOut.model_validate(item) for item in result.scalars().all()]


@admin.post("/users/{user_id}/suspend", response_model=AdminUserOut)
async def suspend_user(user_id: UUID, payload: SuspendUser, db: Db, admin_user: CurrentAdmin) -> AdminUserOut:
    target = await db.get(User, user_id)
    if target is None:
        raise HTTPException(status_code=404, detail="User not found")
    if target.id == admin_user.id or target.is_admin:
        raise HTTPException(status_code=409, detail="Administrator accounts cannot be suspended here")
    target.suspended_at = utcnow()
    target.suspension_reason = payload.reason.strip()
    sessions = await db.execute(select(Session).where(Session.user_id == target.id, Session.revoked_at.is_(None)))
    for session in sessions.scalars().all():
        session.revoked_at = utcnow()
    db.add(AuditLog(actor_user_id=admin_user.id, action="admin.user_suspended", entity_type="user", entity_id=str(target.id), detail=payload.reason))
    await db.commit()
    await db.refresh(target)
    return AdminUserOut.model_validate(target)


@admin.post("/users/{user_id}/restore", response_model=AdminUserOut)
async def restore_user(user_id: UUID, db: Db, admin_user: CurrentAdmin) -> AdminUserOut:
    target = await db.get(User, user_id)
    if target is None or target.deleted_at is not None:
        raise HTTPException(status_code=404, detail="User not found")
    target.suspended_at = None
    target.suspension_reason = None
    target.is_active = True
    db.add(AuditLog(actor_user_id=admin_user.id, action="admin.user_restored", entity_type="user", entity_id=str(target.id)))
    await db.commit()
    await db.refresh(target)
    return AdminUserOut.model_validate(target)


@admin.get("/verifications", response_model=list[IdentityVerificationOut])
async def admin_verifications(db: Db, _: CurrentAdmin, status_filter: VerificationStatus | None = Query(default=None, alias="status")) -> list[IdentityVerificationOut]:
    stmt = select(IdentityVerification).order_by(IdentityVerification.created_at.desc())
    if status_filter:
        stmt = stmt.where(IdentityVerification.status == status_filter)
    result = await db.execute(stmt.limit(200))
    return [IdentityVerificationOut.model_validate(item) for item in result.scalars().all()]


@admin.post("/verifications/{verification_id}/decision", response_model=IdentityVerificationOut)
async def decide_verification(verification_id: UUID, payload: VerificationDecision, db: Db, admin_user: CurrentAdmin) -> IdentityVerificationOut:
    if payload.status not in {VerificationStatus.verified, VerificationStatus.rejected}:
        raise HTTPException(status_code=422, detail="Admin decision must be verified or rejected")
    result = await db.execute(select(IdentityVerification).where(IdentityVerification.id == verification_id).with_for_update())
    verification = result.scalar_one_or_none()
    if verification is None:
        raise HTTPException(status_code=404, detail="Verification not found")
    verification.status = payload.status
    verification.failure_reason = payload.reason if payload.status == VerificationStatus.rejected else None
    verification.verified_at = utcnow() if payload.status == VerificationStatus.verified else None
    target = await db.get(User, verification.user_id)
    if target and payload.status == VerificationStatus.verified:
        target.identity_verified = True
    db.add(AuditLog(actor_user_id=admin_user.id, action="admin.verification_decided", entity_type="identity_verification", entity_id=str(verification.id), detail=payload.status.value))
    await db.commit()
    await db.refresh(verification)
    return IdentityVerificationOut.model_validate(verification)


@admin.get("/disputes", response_model=list[DisputeOut])
async def admin_disputes(db: Db, _: CurrentAdmin, status_filter: DisputeStatus | None = Query(default=None, alias="status")) -> list[DisputeOut]:
    stmt = select(Dispute).order_by(Dispute.created_at.desc())
    if status_filter:
        stmt = stmt.where(Dispute.status == status_filter)
    result = await db.execute(stmt.limit(200))
    return [DisputeOut.model_validate(item) for item in result.scalars().all()]


@admin.post("/disputes/{dispute_id}/resolve", response_model=DisputeOut)
async def resolve_dispute(dispute_id: UUID, payload: AdminDisputeDecision, db: Db, admin_user: CurrentAdmin) -> DisputeOut:
    if payload.status not in {DisputeStatus.resolved, DisputeStatus.closed}:
        raise HTTPException(status_code=422, detail="Resolution status must be resolved or closed")
    result = await db.execute(select(Dispute).where(Dispute.id == dispute_id).with_for_update())
    dispute = result.scalar_one_or_none()
    if dispute is None:
        raise HTTPException(status_code=404, detail="Dispute not found")
    payment = await _payment_for_booking(db, dispute.booking_id)
    booking = await db.get(Booking, dispute.booking_id)
    if payload.refund_paise > 0:
        if payment is None:
            raise HTTPException(status_code=409, detail="This booking has no payment to refund")
        remaining = max(0, payment.amount_paise - payment.refunded_paise)
        if payload.refund_paise > remaining:
            raise HTTPException(status_code=422, detail="Refund exceeds remaining captured amount")
        try:
            refund_reference = await payment_gateway().refund(payment_reference=payment.gateway_reference, amount_paise=payload.refund_paise)
        except RuntimeError as exc:
            raise HTTPException(status_code=503, detail=str(exc)) from exc
        db.add(Refund(payment_id=payment.id, dispute_id=dispute.id, amount_paise=payload.refund_paise, status=RefundStatus.completed, gateway_reference=refund_reference, completed_at=utcnow()))
        payment.refunded_paise += payload.refund_paise
        payment.status = PaymentStatus.refunded if payment.refunded_paise >= payment.amount_paise else PaymentStatus.partially_refunded
        payout = await _payout_for_payment(db, payment.id)
        if payout:
            payout.amount_paise = max(0, payment.amount_paise - payment.platform_fee_paise - payment.refunded_paise)
            payout.hold_reason = None
            if payout.amount_paise == 0:
                payout.status = PayoutStatus.cancelled
            elif booking and booking.status == BookingStatus.completed:
                payout.status = PayoutStatus.eligible
                payout.eligible_at = payout.eligible_at or utcnow()
            else:
                payout.status = PayoutStatus.pending
    elif payment:
        payout = await _payout_for_payment(db, payment.id)
        if payout and payout.status == PayoutStatus.held:
            payout.hold_reason = None
            if booking and booking.status == BookingStatus.completed:
                payout.status = PayoutStatus.eligible
                payout.eligible_at = payout.eligible_at or utcnow()
            else:
                payout.status = PayoutStatus.pending
    dispute.status = payload.status
    dispute.resolution = payload.resolution.strip()
    dispute.resolved_at = utcnow()
    db.add(AuditLog(actor_user_id=admin_user.id, action="admin.dispute_resolved", entity_type="dispute", entity_id=str(dispute.id), detail=f"refund_paise={payload.refund_paise}"))
    await db.commit()
    await db.refresh(dispute)
    return DisputeOut.model_validate(dispute)


@admin.get("/payouts", response_model=list[PayoutOut])
async def admin_payouts(db: Db, _: CurrentAdmin, status_filter: PayoutStatus | None = Query(default=None, alias="status")) -> list[PayoutOut]:
    stmt = select(ProviderPayout).order_by(ProviderPayout.created_at.desc())
    if status_filter:
        stmt = stmt.where(ProviderPayout.status == status_filter)
    result = await db.execute(stmt.limit(200))
    return [PayoutOut.model_validate(item) for item in result.scalars().all()]


@admin.post("/payouts/{payout_id}/process", response_model=PayoutOut)
async def process_payout(payout_id: UUID, payload: AdminPayoutDecision, db: Db, admin_user: CurrentAdmin) -> PayoutOut:
    result = await db.execute(select(ProviderPayout).where(ProviderPayout.id == payout_id).with_for_update())
    payout = result.scalar_one_or_none()
    if payout is None:
        raise HTTPException(status_code=404, detail="Payout not found")
    if payload.status == PayoutStatus.held:
        payout.status = PayoutStatus.held
        payout.hold_reason = "Held by administrator"
    elif payload.status == PayoutStatus.cancelled:
        payout.status = PayoutStatus.cancelled
    elif payload.status == PayoutStatus.paid:
        if payout.status != PayoutStatus.eligible:
            raise HTTPException(status_code=409, detail="Only eligible payouts can be paid")
        try:
            reference = await payout_gateway().send(provider_reference=str(payout.provider_id), amount_paise=payout.amount_paise, currency="INR")
        except RuntimeError as exc:
            raise HTTPException(status_code=503, detail=str(exc)) from exc
        payout.status = PayoutStatus.paid
        payout.gateway_reference = reference
        payout.paid_at = utcnow()
        payout.hold_reason = None
    else:
        raise HTTPException(status_code=422, detail="Unsupported payout admin action")
    db.add(AuditLog(actor_user_id=admin_user.id, action="admin.payout_updated", entity_type="provider_payout", entity_id=str(payout.id), detail=payout.status.value))
    await db.commit()
    await db.refresh(payout)
    return PayoutOut.model_validate(payout)


@admin.get("/risks")
async def admin_risks(db: Db, _: CurrentAdmin, status_filter: RiskSignalStatus | None = Query(default=None, alias="status")):
    stmt = select(RiskSignal).order_by(RiskSignal.created_at.desc())
    if status_filter:
        stmt = stmt.where(RiskSignal.status == status_filter)
    result = await db.execute(stmt.limit(200))
    return [{"id": str(item.id), "entity_type": item.entity_type, "entity_id": item.entity_id, "kind": item.kind, "score": item.score, "detail": item.detail, "status": item.status.value, "created_at": item.created_at, "reviewed_at": item.reviewed_at} for item in result.scalars().all()]


@admin.post("/risks/{risk_id}/decision")
async def decide_risk(risk_id: UUID, payload: RiskDecision, db: Db, admin_user: CurrentAdmin):
    result = await db.execute(select(RiskSignal).where(RiskSignal.id == risk_id).with_for_update())
    risk = result.scalar_one_or_none()
    if risk is None:
        raise HTTPException(status_code=404, detail="Risk signal not found")
    risk.status = payload.status
    risk.reviewed_at = utcnow()
    if payload.detail:
        risk.detail = payload.detail.strip()
    db.add(AuditLog(actor_user_id=admin_user.id, action="admin.risk_reviewed", entity_type="risk_signal", entity_id=str(risk.id), detail=risk.status.value))
    await db.commit()
    return {"id": str(risk.id), "status": risk.status.value}


@admin.get("/reports", response_model=list[ReportOut])
async def admin_reports(db: Db, _: CurrentAdmin, status_filter: ReportStatus | None = Query(default=None, alias="status")) -> list[ReportOut]:
    stmt = select(ContentReport).order_by(ContentReport.created_at.desc())
    if status_filter:
        stmt = stmt.where(ContentReport.status == status_filter)
    result = await db.execute(stmt.limit(200))
    return [ReportOut.model_validate(item) for item in result.scalars().all()]


@admin.post("/reports/{report_id}/decision", response_model=ReportOut)
async def decide_report(report_id: UUID, payload: ReportDecision, db: Db, admin_user: CurrentAdmin) -> ReportOut:
    result = await db.execute(select(ContentReport).where(ContentReport.id == report_id).with_for_update())
    report = result.scalar_one_or_none()
    if report is None:
        raise HTTPException(status_code=404, detail="Report not found")
    report.status = payload.status
    report.resolution = payload.resolution.strip()
    report.reviewed_by_user_id = admin_user.id
    report.resolved_at = utcnow() if payload.status in {ReportStatus.resolved, ReportStatus.dismissed} else None
    db.add(AuditLog(actor_user_id=admin_user.id, action="admin.report_decided", entity_type="content_report", entity_id=str(report.id), detail=report.status.value))
    await db.commit()
    await db.refresh(report)
    return ReportOut.model_validate(report)


@admin.get("/support/cases", response_model=list[SupportCaseOut])
async def admin_support_cases(db: Db, _: CurrentAdmin, status_filter: CaseStatus | None = Query(default=None, alias="status")) -> list[SupportCaseOut]:
    stmt = select(SupportCase).order_by(SupportCase.updated_at.desc())
    if status_filter:
        stmt = stmt.where(SupportCase.status == status_filter)
    result = await db.execute(stmt.limit(200))
    return [SupportCaseOut.model_validate(item) for item in result.scalars().all()]


@admin.post("/support/cases/{case_id}/decision", response_model=SupportCaseOut)
async def decide_support_case(case_id: UUID, payload: SupportDecision, db: Db, admin_user: CurrentAdmin) -> SupportCaseOut:
    result = await db.execute(select(SupportCase).where(SupportCase.id == case_id).with_for_update())
    case = result.scalar_one_or_none()
    if case is None:
        raise HTTPException(status_code=404, detail="Support case not found")
    case.status = payload.status
    if payload.priority is not None:
        case.priority = payload.priority
    if payload.assign_to_me:
        case.assigned_admin_user_id = admin_user.id
    case.updated_at = utcnow()
    db.add(AuditLog(actor_user_id=admin_user.id, action="admin.support_updated", entity_type="support_case", entity_id=str(case.id), detail=case.status.value))
    await db.commit()
    await db.refresh(case)
    return SupportCaseOut.model_validate(case)


@admin.get("/warranty-claims", response_model=list[WarrantyOut])
async def admin_warranty_claims(db: Db, _: CurrentAdmin, status_filter: WarrantyStatus | None = Query(default=None, alias="status")) -> list[WarrantyOut]:
    stmt = select(WarrantyClaim).order_by(WarrantyClaim.created_at.desc())
    if status_filter:
        stmt = stmt.where(WarrantyClaim.status == status_filter)
    result = await db.execute(stmt.limit(200))
    return [WarrantyOut.model_validate(item) for item in result.scalars().all()]


@admin.post("/warranty-claims/{claim_id}/decision", response_model=WarrantyOut)
async def decide_warranty_claim(claim_id: UUID, payload: WarrantyDecision, db: Db, admin_user: CurrentAdmin) -> WarrantyOut:
    result = await db.execute(select(WarrantyClaim).where(WarrantyClaim.id == claim_id).with_for_update())
    claim = result.scalar_one_or_none()
    if claim is None:
        raise HTTPException(status_code=404, detail="Warranty claim not found")
    claim.status = payload.status
    claim.resolution = payload.resolution.strip()
    claim.resolved_at = utcnow() if payload.status in {WarrantyStatus.resolved, WarrantyStatus.rejected} else None
    db.add(AuditLog(actor_user_id=admin_user.id, action="admin.warranty_decided", entity_type="warranty_claim", entity_id=str(claim.id), detail=claim.status.value))
    await db.commit()
    await db.refresh(claim)
    return WarrantyOut.model_validate(claim)


@admin.post("/media/{media_id}/quarantine", response_model=MediaOut)
async def quarantine_media(media_id: UUID, db: Db, admin_user: CurrentAdmin) -> MediaOut:
    media = await db.get(MediaAttachment, media_id)
    if media is None:
        raise HTTPException(status_code=404, detail="Media attachment not found")
    media.status = MediaStatus.quarantined
    db.add(AuditLog(actor_user_id=admin_user.id, action="admin.media_quarantined", entity_type="media_attachment", entity_id=str(media.id)))
    await db.commit()
    await db.refresh(media)
    return MediaOut.model_validate(media)


@admin.get("/audit")
async def admin_audit(db: Db, _: CurrentAdmin, action: str | None = Query(default=None, max_length=120), limit: int = Query(default=100, ge=1, le=500)):
    stmt = select(AuditLog).order_by(AuditLog.created_at.desc())
    if action:
        stmt = stmt.where(AuditLog.action.ilike(f"%{action.strip()}%"))
    result = await db.execute(stmt.limit(limit))
    return [{"id": str(item.id), "actor_user_id": str(item.actor_user_id) if item.actor_user_id else None, "action": item.action, "entity_type": item.entity_type, "entity_id": item.entity_id, "detail": item.detail, "created_at": item.created_at} for item in result.scalars().all()]


router.include_router(ops)
router.include_router(admin)
