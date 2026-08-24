from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import or_, select

from ..deps import CurrentProvider, CurrentUser, Db
from ..models import AuditLog, BidEvent, Booking, BookingStatus, ProviderProfile, RequestStatus, ServiceListing, ServiceRequest
from ..schemas import BidCreate, BidOut, BookingOut, DirectBookingCreate, ProviderOut, ProviderUpsert, RequestCreate, RequestOut, ServiceCreate, ServiceOut

router = APIRouter(tags=["marketplace"])


async def _provider_for_user(db: Db, user_id: UUID) -> ProviderProfile | None:
    result = await db.execute(select(ProviderProfile).where(ProviderProfile.user_id == user_id))
    return result.scalar_one_or_none()


@router.put("/providers/me", response_model=ProviderOut)
async def upsert_provider(payload: ProviderUpsert, db: Db, user: CurrentUser) -> ProviderOut:
    provider = await _provider_for_user(db, user.id)
    if provider is None:
        provider = ProviderProfile(user_id=user.id, **payload.model_dump())
        db.add(provider)
    else:
        for key, value in payload.model_dump().items():
            setattr(provider, key, value)
        provider.active = True
    user.display_name = payload.display_name
    await db.commit()
    await db.refresh(provider)
    return ProviderOut.model_validate(provider)


@router.get("/providers/me", response_model=ProviderOut | None)
async def get_my_provider(db: Db, user: CurrentUser) -> ProviderOut | None:
    provider = await _provider_for_user(db, user.id)
    return ProviderOut.model_validate(provider) if provider else None


@router.post("/services", response_model=ServiceOut, status_code=201)
async def create_service(payload: ServiceCreate, db: Db, provider: CurrentProvider) -> ServiceOut:
    listing = ServiceListing(provider_id=provider.id, **payload.model_dump())
    db.add(listing)
    await db.commit()
    await db.refresh(listing)
    return ServiceOut.model_validate(listing)


@router.get("/services", response_model=list[ServiceOut])
async def list_services(
    db: Db,
    category: str | None = None,
    area: str | None = None,
    limit: int = Query(default=50, ge=1, le=100),
) -> list[ServiceOut]:
    stmt = select(ServiceListing).where(ServiceListing.active.is_(True)).order_by(ServiceListing.created_at.desc())
    if category:
        stmt = stmt.where(ServiceListing.category.ilike(f"%{category}%"))
    if area:
        stmt = stmt.where(ServiceListing.area.ilike(f"%{area}%"))
    result = await db.execute(stmt.limit(limit))
    return [ServiceOut.model_validate(item) for item in result.scalars().all()]


@router.post("/services/{listing_id}/book", response_model=BookingOut, status_code=201)
async def direct_book(listing_id: UUID, payload: DirectBookingCreate, db: Db, user: CurrentUser) -> BookingOut:
    listing = await db.get(ServiceListing, listing_id)
    if listing is None or not listing.active:
        raise HTTPException(status_code=404, detail="Service listing not found")
    provider = await db.get(ProviderProfile, listing.provider_id)
    if provider is None or provider.user_id == user.id:
        raise HTTPException(status_code=409, detail="You cannot book your own service")
    booking = Booking(
        customer_user_id=user.id,
        provider_id=provider.id,
        service_listing_id=listing.id,
        agreed_amount_paise=listing.price_paise,
        scheduled_for=payload.scheduled_for,
        area=payload.area,
        status=BookingStatus.confirmed,
    )
    db.add(booking)
    await db.flush()
    db.add(AuditLog(actor_user_id=user.id, action="booking.direct_created", entity_type="booking", entity_id=str(booking.id)))
    await db.commit()
    await db.refresh(booking)
    return BookingOut.model_validate(booking)


@router.post("/requests", response_model=RequestOut, status_code=201)
async def create_request(payload: RequestCreate, db: Db, user: CurrentUser) -> RequestOut:
    request = ServiceRequest(created_by_user_id=user.id, **payload.model_dump())
    db.add(request)
    await db.commit()
    await db.refresh(request)
    return RequestOut.model_validate(request)


@router.get("/requests", response_model=list[RequestOut])
async def list_requests(
    db: Db,
    status_filter: RequestStatus | None = Query(default=None, alias="status"),
    limit: int = Query(default=50, ge=1, le=100),
) -> list[RequestOut]:
    stmt = select(ServiceRequest).order_by(ServiceRequest.created_at.desc())
    if status_filter:
        stmt = stmt.where(ServiceRequest.status == status_filter)
    result = await db.execute(stmt.limit(limit))
    return [RequestOut.model_validate(item) for item in result.scalars().all()]


@router.post("/requests/{request_id}/bids", response_model=BidOut, status_code=201)
async def submit_bid(
    request_id: UUID,
    payload: BidCreate,
    db: Db,
    user: CurrentUser,
    provider: CurrentProvider,
) -> BidOut:
    request = await db.get(ServiceRequest, request_id)
    if request is None:
        raise HTTPException(status_code=404, detail="Request not found")
    if request.status != RequestStatus.bidding:
        raise HTTPException(status_code=409, detail="Bidding is closed")
    if request.created_by_user_id == user.id:
        raise HTTPException(status_code=409, detail="You cannot bid on your own request")

    previous_result = await db.execute(
        select(BidEvent)
        .where(BidEvent.request_id == request_id, BidEvent.provider_id == provider.id)
        .order_by(BidEvent.submitted_at.desc())
        .limit(1)
    )
    previous = previous_result.scalar_one_or_none()
    bid = BidEvent(
        request_id=request_id,
        provider_id=provider.id,
        amount_paise=payload.amount_paise,
        note=payload.note,
        previous_bid_event_id=previous.id if previous else None,
    )
    db.add(bid)
    await db.flush()
    db.add(AuditLog(actor_user_id=user.id, action="bid.appended", entity_type="bid_event", entity_id=str(bid.id)))
    await db.commit()
    await db.refresh(bid)
    return BidOut.model_validate(bid).model_copy(update={"is_current_offer": True})


@router.get("/requests/{request_id}/bids", response_model=list[BidOut])
async def bid_history(request_id: UUID, db: Db) -> list[BidOut]:
    result = await db.execute(
        select(BidEvent).where(BidEvent.request_id == request_id).order_by(BidEvent.submitted_at.desc())
    )
    events = list(result.scalars().all())
    latest_provider_ids: set[UUID] = set()
    output: list[BidOut] = []
    for event in events:
        is_current = event.provider_id not in latest_provider_ids
        latest_provider_ids.add(event.provider_id)
        output.append(BidOut.model_validate(event).model_copy(update={"is_current_offer": is_current}))
    return output


@router.post("/requests/{request_id}/award/{bid_id}", response_model=BookingOut, status_code=201)
async def award_bid(request_id: UUID, bid_id: UUID, db: Db, user: CurrentUser) -> BookingOut:
    request_result = await db.execute(
        select(ServiceRequest).where(ServiceRequest.id == request_id).with_for_update()
    )
    request = request_result.scalar_one_or_none()
    if request is None:
        raise HTTPException(status_code=404, detail="Request not found")
    if request.created_by_user_id != user.id:
        raise HTTPException(status_code=403, detail="Only the request owner can accept a bid")
    if request.status != RequestStatus.bidding:
        raise HTTPException(status_code=409, detail="Request is no longer open for bidding")

    bid = await db.get(BidEvent, bid_id)
    if bid is None or bid.request_id != request.id:
        raise HTTPException(status_code=404, detail="Bid not found for this request")

    latest_result = await db.execute(
        select(BidEvent)
        .where(BidEvent.request_id == request.id, BidEvent.provider_id == bid.provider_id)
        .order_by(BidEvent.submitted_at.desc())
        .limit(1)
    )
    latest = latest_result.scalar_one()
    if latest.id != bid.id:
        raise HTTPException(status_code=409, detail="Historical bids cannot be awarded; select the provider's latest offer")

    booking = Booking(
        customer_user_id=user.id,
        provider_id=bid.provider_id,
        request_id=request.id,
        accepted_bid_event_id=bid.id,
        agreed_amount_paise=bid.amount_paise,
        scheduled_for=request.requested_for,
        area=request.area,
        status=BookingStatus.confirmed,
    )
    db.add(booking)
    await db.flush()
    request.status = RequestStatus.booked
    request.accepted_bid_event_id = bid.id
    request.booking_id = booking.id
    db.add(AuditLog(actor_user_id=user.id, action="request.bid_awarded", entity_type="booking", entity_id=str(booking.id), detail=f"bid_event_id={bid.id}"))
    await db.commit()
    await db.refresh(booking)
    return BookingOut.model_validate(booking)


@router.get("/bookings", response_model=list[BookingOut])
async def my_bookings(db: Db, user: CurrentUser) -> list[BookingOut]:
    provider = await _provider_for_user(db, user.id)
    clauses = [Booking.customer_user_id == user.id]
    if provider:
        clauses.append(Booking.provider_id == provider.id)
    result = await db.execute(select(Booking).where(or_(*clauses)).order_by(Booking.created_at.desc()))
    return [BookingOut.model_validate(item) for item in result.scalars().all()]
