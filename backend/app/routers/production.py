from __future__ import annotations

import math
from datetime import datetime
from enum import Enum
from uuid import UUID

import httpx
from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import func, or_, select

from ..admin_mfa import create_admin_stepup_token, verify_admin_totp
from ..communication_models import Notification
from ..config import settings
from ..deps import CurrentAdmin, CurrentUser, Db
from ..models import (
    AuditLog,
    Booking,
    Group,
    GroupMember,
    ProviderProfile,
    ServiceListing,
    ServiceRequest,
    User,
)
from ..ops_models import UserBlock
from ..production_models import BookingAssignment, ProviderExtendedProfile, ProviderStaff
from ..production_schemas import (
    AdminStepUpOut,
    AdminStepUpRequest,
    AssignmentCreate,
    AssignmentOut,
    DataExportOut,
    IdentityLaunchOut,
    NearbyServiceOut,
    ProviderExtendedOut,
    ProviderExtendedUpdate,
    StaffCreate,
    StaffOut,
)
from ..security import normalize_indian_phone, utcnow
from ..trust_models import Dispute, IdentityVerification, Payment, ProviderPayout, Review, VerificationStatus

router = APIRouter(prefix="/production", tags=["production-launch"])


def _csv(values: list[str]) -> str:
    return ",".join(sorted({item.strip() for item in values if item.strip()}))


def _split(value: str) -> list[str]:
    return [item for item in (part.strip() for part in value.split(",")) if item]


def _extended_out(item: ProviderExtendedProfile) -> ProviderExtendedOut:
    return ProviderExtendedOut(
        provider_id=item.provider_id,
        years_experience=item.years_experience,
        languages=_split(item.languages_csv),
        skills=_split(item.skills_csv),
        gstin=item.gstin,
        service_radius_km=item.service_radius_km,
        latitude=item.latitude,
        longitude=item.longitude,
        payout_configured=bool(item.payout_account_reference),
        payout_method_label=item.payout_method_label,
        portfolio_headline=item.portfolio_headline,
        updated_at=item.updated_at,
    )


async def _provider_for_user(db: Db, user_id: UUID) -> ProviderProfile | None:
    result = await db.execute(select(ProviderProfile).where(ProviderProfile.user_id == user_id))
    return result.scalar_one_or_none()


async def _managed_provider(db: Db, user_id: UUID) -> ProviderProfile | None:
    own = await _provider_for_user(db, user_id)
    if own is not None:
        return own
    result = await db.execute(
        select(ProviderProfile)
        .join(ProviderStaff, ProviderStaff.provider_id == ProviderProfile.id)
        .where(
            ProviderStaff.user_id == user_id,
            ProviderStaff.active.is_(True),
            ProviderStaff.role.in_(["owner", "manager", "dispatcher"]),
        )
    )
    return result.scalars().first()


def _jsonable(value):
    if value is None or isinstance(value, (str, int, float, bool)):
        return value
    if isinstance(value, (UUID, datetime)):
        return str(value)
    if isinstance(value, Enum):
        return value.value
    return str(value)


def _model_dict(item) -> dict:
    return {column.name: _jsonable(getattr(item, column.name)) for column in item.__table__.columns}


def _distance_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    radius = 6371.0088
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return radius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


@router.post("/admin/step-up", response_model=AdminStepUpOut)
async def admin_step_up(payload: AdminStepUpRequest, admin: CurrentAdmin) -> AdminStepUpOut:
    if settings.environment != "production":
        return AdminStepUpOut(
            token=create_admin_stepup_token(admin.id),
            expires_in_seconds=settings.admin_stepup_minutes * 60,
        )
    if not verify_admin_totp(payload.code):
        raise HTTPException(status_code=401, detail="Incorrect administrator authenticator code")
    return AdminStepUpOut(
        token=create_admin_stepup_token(admin.id),
        expires_in_seconds=settings.admin_stepup_minutes * 60,
    )


@router.get("/provider/profile", response_model=ProviderExtendedOut)
async def get_provider_extended(db: Db, user: CurrentUser) -> ProviderExtendedOut:
    provider = await _provider_for_user(db, user.id)
    if provider is None:
        raise HTTPException(status_code=404, detail="Provider profile not found")
    item = await db.get(ProviderExtendedProfile, provider.id)
    if item is None:
        item = ProviderExtendedProfile(provider_id=provider.id)
        db.add(item)
        await db.commit()
        await db.refresh(item)
    return _extended_out(item)


@router.put("/provider/profile", response_model=ProviderExtendedOut)
async def update_provider_extended(
    payload: ProviderExtendedUpdate,
    db: Db,
    user: CurrentUser,
) -> ProviderExtendedOut:
    provider = await _provider_for_user(db, user.id)
    if provider is None:
        raise HTTPException(status_code=404, detail="Provider profile not found")
    if (payload.latitude is None) != (payload.longitude is None):
        raise HTTPException(status_code=422, detail="Latitude and longitude must be supplied together")
    item = await db.get(ProviderExtendedProfile, provider.id)
    if item is None:
        item = ProviderExtendedProfile(provider_id=provider.id)
        db.add(item)
    item.years_experience = payload.years_experience
    item.languages_csv = _csv(payload.languages)
    item.skills_csv = _csv(payload.skills)
    item.gstin = payload.gstin.strip().upper() if payload.gstin else None
    item.service_radius_km = payload.service_radius_km
    item.latitude = payload.latitude
    item.longitude = payload.longitude
    item.payout_account_reference = payload.payout_account_reference.strip() if payload.payout_account_reference else None
    item.payout_method_label = payload.payout_method_label.strip() if payload.payout_method_label else None
    item.portfolio_headline = payload.portfolio_headline.strip() if payload.portfolio_headline else None
    item.updated_at = utcnow()
    db.add(AuditLog(actor_user_id=user.id, action="provider.extended_updated", entity_type="provider", entity_id=str(provider.id)))
    await db.commit()
    await db.refresh(item)
    return _extended_out(item)


@router.get("/provider/staff", response_model=list[StaffOut])
async def list_staff(db: Db, user: CurrentUser) -> list[StaffOut]:
    provider = await _managed_provider(db, user.id)
    if provider is None:
        raise HTTPException(status_code=403, detail="Provider management access required")
    result = await db.execute(
        select(ProviderStaff).where(ProviderStaff.provider_id == provider.id).order_by(ProviderStaff.created_at.asc())
    )
    return [StaffOut.model_validate(item) for item in result.scalars().all()]


@router.post("/provider/staff", response_model=StaffOut, status_code=201)
async def add_staff(payload: StaffCreate, db: Db, user: CurrentUser) -> StaffOut:
    provider = await _provider_for_user(db, user.id)
    if provider is None:
        raise HTTPException(status_code=403, detail="Only the provider owner can add staff")
    phone = normalize_indian_phone(payload.phone)
    result = await db.execute(select(User).where(User.phone == phone, User.is_active.is_(True), User.deleted_at.is_(None)))
    staff_user = result.scalar_one_or_none()
    if staff_user is None:
        raise HTTPException(status_code=404, detail="Staff member must create a Bid&Book account first")
    existing = await db.execute(
        select(ProviderStaff).where(ProviderStaff.provider_id == provider.id, ProviderStaff.user_id == staff_user.id)
    )
    item = existing.scalar_one_or_none()
    if item is None:
        item = ProviderStaff(provider_id=provider.id, user_id=staff_user.id, role=payload.role)
        db.add(item)
    else:
        item.role = payload.role
        item.active = True
    db.add(AuditLog(actor_user_id=user.id, action="provider.staff_added", entity_type="provider", entity_id=str(provider.id), detail=f"staff_user_id={staff_user.id};role={payload.role}"))
    await db.commit()
    await db.refresh(item)
    return StaffOut.model_validate(item)


@router.delete("/provider/staff/{staff_user_id}", status_code=204)
async def deactivate_staff(staff_user_id: UUID, db: Db, user: CurrentUser) -> None:
    provider = await _provider_for_user(db, user.id)
    if provider is None:
        raise HTTPException(status_code=403, detail="Only the provider owner can remove staff")
    result = await db.execute(
        select(ProviderStaff).where(ProviderStaff.provider_id == provider.id, ProviderStaff.user_id == staff_user_id)
    )
    item = result.scalar_one_or_none()
    if item is None:
        raise HTTPException(status_code=404, detail="Staff member not found")
    item.active = False
    db.add(AuditLog(actor_user_id=user.id, action="provider.staff_removed", entity_type="provider", entity_id=str(provider.id), detail=f"staff_user_id={staff_user_id}"))
    await db.commit()


@router.post("/bookings/{booking_id}/assignment", response_model=AssignmentOut)
async def assign_booking(
    booking_id: UUID,
    payload: AssignmentCreate,
    db: Db,
    user: CurrentUser,
) -> AssignmentOut:
    provider = await _managed_provider(db, user.id)
    if provider is None:
        raise HTTPException(status_code=403, detail="Provider dispatch access required")
    booking = await db.get(Booking, booking_id)
    if booking is None or booking.provider_id != provider.id:
        raise HTTPException(status_code=404, detail="Booking not found")
    staff_result = await db.execute(
        select(ProviderStaff).where(
            ProviderStaff.provider_id == provider.id,
            ProviderStaff.user_id == payload.staff_user_id,
            ProviderStaff.active.is_(True),
            ProviderStaff.role.in_(["owner", "manager", "technician"]),
        )
    )
    staff = staff_result.scalar_one_or_none()
    if staff is None:
        raise HTTPException(status_code=422, detail="Choose an active technician or manager from this provider")
    existing = await db.execute(select(BookingAssignment).where(BookingAssignment.booking_id == booking.id))
    item = existing.scalar_one_or_none()
    if item is None:
        item = BookingAssignment(
            booking_id=booking.id,
            staff_user_id=payload.staff_user_id,
            assigned_by_user_id=user.id,
        )
        db.add(item)
    else:
        item.staff_user_id = payload.staff_user_id
        item.assigned_by_user_id = user.id
        item.assigned_at = utcnow()
    db.add(AuditLog(actor_user_id=user.id, action="booking.technician_assigned", entity_type="booking", entity_id=str(booking.id), detail=f"staff_user_id={payload.staff_user_id}"))
    await db.commit()
    await db.refresh(item)
    return AssignmentOut.model_validate(item)


@router.get("/bookings/{booking_id}/assignment", response_model=AssignmentOut | None)
async def booking_assignment(booking_id: UUID, db: Db, user: CurrentUser) -> AssignmentOut | None:
    booking = await db.get(Booking, booking_id)
    if booking is None:
        raise HTTPException(status_code=404, detail="Booking not found")
    provider = await db.get(ProviderProfile, booking.provider_id)
    can_view = booking.customer_user_id == user.id or (provider is not None and provider.user_id == user.id)
    if not can_view:
        staff = await db.execute(
            select(ProviderStaff.id).where(ProviderStaff.provider_id == booking.provider_id, ProviderStaff.user_id == user.id, ProviderStaff.active.is_(True))
        )
        can_view = staff.scalar_one_or_none() is not None
    if not can_view:
        raise HTTPException(status_code=403, detail="Booking participant access required")
    result = await db.execute(select(BookingAssignment).where(BookingAssignment.booking_id == booking.id))
    item = result.scalar_one_or_none()
    return AssignmentOut.model_validate(item) if item else None


@router.get("/discovery/nearby", response_model=list[NearbyServiceOut])
async def nearby_services(
    db: Db,
    user: CurrentUser,
    latitude: float = Query(ge=-90, le=90),
    longitude: float = Query(ge=-180, le=180),
    radius_km: int = Query(default=25, ge=1, le=100),
    category: str | None = Query(default=None, max_length=100),
    verified_only: bool = False,
    limit: int = Query(default=50, ge=1, le=100),
) -> list[NearbyServiceOut]:
    rating_subquery = (
        select(
            Review.subject_provider_id.label("provider_id"),
            func.avg(Review.rating).label("rating"),
            func.count(Review.id).label("review_count"),
        )
        .where(Review.subject_provider_id.is_not(None))
        .group_by(Review.subject_provider_id)
        .subquery()
    )
    blocked = select(UserBlock.blocked_user_id).where(UserBlock.blocker_user_id == user.id)
    stmt = (
        select(ServiceListing, ProviderProfile, ProviderExtendedProfile, User, rating_subquery.c.rating, rating_subquery.c.review_count)
        .join(ProviderProfile, ProviderProfile.id == ServiceListing.provider_id)
        .join(User, User.id == ProviderProfile.user_id)
        .join(ProviderExtendedProfile, ProviderExtendedProfile.provider_id == ProviderProfile.id)
        .outerjoin(rating_subquery, rating_subquery.c.provider_id == ProviderProfile.id)
        .where(
            ServiceListing.active.is_(True),
            ProviderProfile.active.is_(True),
            ProviderExtendedProfile.latitude.is_not(None),
            ProviderExtendedProfile.longitude.is_not(None),
            User.is_active.is_(True),
            User.suspended_at.is_(None),
            User.id.not_in(blocked),
        )
    )
    if category:
        stmt = stmt.where(ServiceListing.category.ilike(f"%{category.strip()}%"))
    if verified_only:
        stmt = stmt.where(User.identity_verified.is_(True))
    rows = await db.execute(stmt.limit(300))
    output: list[NearbyServiceOut] = []
    for listing, provider, extended, provider_user, rating, review_count in rows.all():
        distance = _distance_km(latitude, longitude, float(extended.latitude), float(extended.longitude))
        effective_radius = min(radius_km, extended.service_radius_km)
        if distance > effective_radius:
            continue
        output.append(
            NearbyServiceOut(
                id=listing.id,
                provider_id=provider.id,
                provider_name=provider.display_name,
                provider_verified=provider_user.identity_verified,
                title=listing.title,
                category=listing.category,
                description=listing.description,
                area=listing.area,
                price_paise=listing.price_paise,
                pricing_unit=listing.pricing_unit.value,
                distance_km=round(distance, 2),
                rating=round(float(rating), 2) if rating is not None else None,
                review_count=int(review_count or 0),
                service_radius_km=extended.service_radius_km,
            )
        )
    output.sort(key=lambda item: (item.distance_km if item.distance_km is not None else 10_000, -(item.rating or 0)))
    return output[:limit]


@router.get("/account/export", response_model=DataExportOut)
async def export_account(db: Db, user: CurrentUser) -> DataExportOut:
    provider = await _provider_for_user(db, user.id)
    services = []
    payouts = []
    if provider:
        services_result = await db.execute(select(ServiceListing).where(ServiceListing.provider_id == provider.id))
        services = [_model_dict(item) for item in services_result.scalars().all()]
        payouts_result = await db.execute(select(ProviderPayout).where(ProviderPayout.provider_id == provider.id))
        payouts = [_model_dict(item) for item in payouts_result.scalars().all()]
    requests_result = await db.execute(select(ServiceRequest).where(ServiceRequest.created_by_user_id == user.id))
    bookings_result = await db.execute(
        select(Booking).where(or_(Booking.customer_user_id == user.id, Booking.provider_id == (provider.id if provider else UUID(int=0))))
    )
    payments_result = await db.execute(select(Payment).where(Payment.customer_user_id == user.id))
    reviews_result = await db.execute(select(Review).where(or_(Review.reviewer_user_id == user.id, Review.subject_user_id == user.id)))
    disputes_result = await db.execute(select(Dispute).where(or_(Dispute.opened_by_user_id == user.id, Dispute.against_user_id == user.id)))
    groups_result = await db.execute(select(Group).join(GroupMember, GroupMember.group_id == Group.id).where(GroupMember.user_id == user.id))
    notifications_result = await db.execute(select(Notification).where(Notification.user_id == user.id))
    return DataExportOut(
        generated_at=utcnow(),
        user=_model_dict(user),
        provider=_model_dict(provider) if provider else None,
        services=services,
        requests=[_model_dict(item) for item in requests_result.scalars().all()],
        bookings=[_model_dict(item) for item in bookings_result.scalars().all()],
        payments=[_model_dict(item) for item in payments_result.scalars().all()],
        payouts=payouts,
        reviews=[_model_dict(item) for item in reviews_result.scalars().all()],
        disputes=[_model_dict(item) for item in disputes_result.scalars().all()],
        groups=[_model_dict(item) for item in groups_result.scalars().unique().all()],
        notifications=[_model_dict(item) for item in notifications_result.scalars().all()],
    )


@router.post("/identity/verifications/{verification_id}/launch", response_model=IdentityLaunchOut)
async def launch_identity_verification(
    verification_id: UUID,
    db: Db,
    user: CurrentUser,
) -> IdentityLaunchOut:
    result = await db.execute(
        select(IdentityVerification).where(
            IdentityVerification.id == verification_id,
            IdentityVerification.user_id == user.id,
        )
    )
    verification = result.scalar_one_or_none()
    if verification is None:
        raise HTTPException(status_code=404, detail="Verification not found")
    if verification.status != VerificationStatus.pending:
        raise HTTPException(status_code=409, detail="Verification is not pending")
    if not settings.identity_http_url or not settings.identity_http_token:
        raise HTTPException(status_code=503, detail="Production identity provider is not configured")
    callback_url = f"{settings.public_api_url.rstrip('/')}/webhooks/identity"
    try:
        async with httpx.AsyncClient(timeout=15) as client:
            response = await client.post(
                settings.identity_http_url,
                headers={"Authorization": f"Bearer {settings.identity_http_token}"},
                json={
                    "reference": verification.provider_reference,
                    "method": verification.method.value,
                    "user_id": str(user.id),
                    "callback_url": callback_url,
                },
            )
            response.raise_for_status()
            body = response.json()
    except (httpx.HTTPError, ValueError) as exc:
        raise HTTPException(status_code=502, detail="Identity provider could not start verification") from exc
    launch_url = body.get("launch_url") if isinstance(body, dict) else None
    if not isinstance(launch_url, str) or not launch_url.startswith("https://"):
        raise HTTPException(status_code=502, detail="Identity provider returned an invalid launch URL")
    return IdentityLaunchOut(
        verification_id=verification.id,
        provider_reference=verification.provider_reference,
        launch_url=launch_url,
    )
