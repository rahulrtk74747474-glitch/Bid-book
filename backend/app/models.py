from __future__ import annotations

import enum
from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import Boolean, CheckConstraint, DateTime, Enum, ForeignKey, Index, Integer, String, Text, UniqueConstraint, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from .database import Base
from .security import utcnow


class ProviderKind(str, enum.Enum):
    individual = "individual"
    company = "company"


class RequestStatus(str, enum.Enum):
    bidding = "bidding"
    booked = "booked"
    completed = "completed"
    cancelled = "cancelled"


class PricingUnit(str, enum.Enum):
    fixed = "fixed"
    hourly = "hourly"
    daily = "daily"
    per_unit = "per_unit"
    quote = "quote"


class GroupRole(str, enum.Enum):
    owner = "owner"
    admin = "admin"
    member = "member"


class ProposalStatus(str, enum.Enum):
    voting = "voting"
    published = "published"
    closed = "closed"


class VoteChoice(str, enum.Enum):
    accept = "accept"
    reject = "reject"
    maybe = "maybe"


class BookingStatus(str, enum.Enum):
    confirmed = "confirmed"
    in_progress = "in_progress"
    completed = "completed"
    cancelled = "cancelled"


class User(Base):
    __tablename__ = "users"
    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    phone: Mapped[str] = mapped_column(String(16), unique=True, index=True)
    display_name: Mapped[str | None] = mapped_column(String(120))
    phone_verified: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    identity_verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_admin: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False, index=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    suspended_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), index=True)
    suspension_reason: Mapped[str | None] = mapped_column(String(500))
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class OtpChallenge(Base):
    __tablename__ = "otp_challenges"
    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    phone: Mapped[str] = mapped_column(String(16), index=True)
    code_digest: Mapped[str | None] = mapped_column(String(64))
    attempts: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    max_attempts: Mapped[int] = mapped_column(Integer, nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    consumed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, index=True)
    __table_args__ = (Index("ix_otp_phone_created", "phone", "created_at"),)


class Session(Base):
    __tablename__ = "sessions"
    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), index=True)
    refresh_hash: Mapped[str] = mapped_column(String(64), unique=True)
    device_id: Mapped[str | None] = mapped_column(String(200))
    user_agent: Mapped[str | None] = mapped_column(String(400))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    last_used_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class ProviderProfile(Base):
    __tablename__ = "provider_profiles"
    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), unique=True)
    kind: Mapped[ProviderKind] = mapped_column(Enum(ProviderKind), nullable=False)
    display_name: Mapped[str] = mapped_column(String(140), nullable=False)
    service_area: Mapped[str] = mapped_column(String(180), nullable=False)
    bio: Mapped[str | None] = mapped_column(Text)
    active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class ServiceListing(Base):
    __tablename__ = "service_listings"
    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    provider_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("provider_profiles.id", ondelete="CASCADE"), index=True)
    title: Mapped[str] = mapped_column(String(160), nullable=False)
    category: Mapped[str] = mapped_column(String(100), index=True)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    area: Mapped[str] = mapped_column(String(180), index=True)
    price_paise: Mapped[int] = mapped_column(Integer, nullable=False)
    pricing_unit: Mapped[PricingUnit] = mapped_column(Enum(PricingUnit), nullable=False)
    active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    __table_args__ = (CheckConstraint("price_paise >= 0", name="ck_service_price_nonnegative"),)


class ServiceRequest(Base):
    __tablename__ = "service_requests"
    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    created_by_user_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("users.id"), index=True)
    group_id: Mapped[UUID | None] = mapped_column(Uuid, ForeignKey("groups.id", ondelete="SET NULL"), index=True)
    title: Mapped[str] = mapped_column(String(180), nullable=False)
    category: Mapped[str] = mapped_column(String(100), index=True)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    area: Mapped[str] = mapped_column(String(180), index=True)
    requested_for: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    status: Mapped[RequestStatus] = mapped_column(Enum(RequestStatus), default=RequestStatus.bidding, index=True)
    accepted_bid_event_id: Mapped[UUID | None] = mapped_column(Uuid, nullable=True)
    booking_id: Mapped[UUID | None] = mapped_column(Uuid, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, index=True)


class BidEvent(Base):
    __tablename__ = "bid_events"
    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    request_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("service_requests.id", ondelete="CASCADE"), index=True)
    provider_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("provider_profiles.id"), index=True)
    amount_paise: Mapped[int] = mapped_column(Integer, nullable=False)
    note: Mapped[str | None] = mapped_column(Text)
    previous_bid_event_id: Mapped[UUID | None] = mapped_column(Uuid, ForeignKey("bid_events.id"))
    submitted_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, index=True)
    __table_args__ = (
        CheckConstraint("amount_paise > 0", name="ck_bid_amount_positive"),
        Index("ix_bid_request_provider_time", "request_id", "provider_id", "submitted_at"),
    )


class Booking(Base):
    __tablename__ = "bookings"
    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    customer_user_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("users.id"), index=True)
    provider_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("provider_profiles.id"), index=True)
    service_listing_id: Mapped[UUID | None] = mapped_column(Uuid, ForeignKey("service_listings.id", ondelete="SET NULL"))
    request_id: Mapped[UUID | None] = mapped_column(Uuid, ForeignKey("service_requests.id", ondelete="SET NULL"), index=True)
    accepted_bid_event_id: Mapped[UUID | None] = mapped_column(Uuid, ForeignKey("bid_events.id"))
    agreed_amount_paise: Mapped[int] = mapped_column(Integer, nullable=False)
    scheduled_for: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    area: Mapped[str] = mapped_column(String(180), nullable=False)
    status: Mapped[BookingStatus] = mapped_column(Enum(BookingStatus), default=BookingStatus.confirmed, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    __table_args__ = (CheckConstraint("agreed_amount_paise >= 0", name="ck_booking_amount_nonnegative"),)


class Group(Base):
    __tablename__ = "groups"
    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    name: Mapped[str] = mapped_column(String(160), nullable=False)
    area: Mapped[str] = mapped_column(String(180), nullable=False, index=True)
    owner_user_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("users.id"), index=True)
    invite_code: Mapped[str] = mapped_column(String(16), unique=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class GroupMember(Base):
    __tablename__ = "group_members"
    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    group_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("groups.id", ondelete="CASCADE"), index=True)
    user_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), index=True)
    role: Mapped[GroupRole] = mapped_column(Enum(GroupRole), default=GroupRole.member)
    joined_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    __table_args__ = (UniqueConstraint("group_id", "user_id", name="uq_group_member"),)


class GroupProposal(Base):
    __tablename__ = "group_proposals"
    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    group_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("groups.id", ondelete="CASCADE"), index=True)
    created_by_user_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("users.id"))
    title: Mapped[str] = mapped_column(String(180), nullable=False)
    category: Mapped[str] = mapped_column(String(100), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    preferred_for: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    status: Mapped[ProposalStatus] = mapped_column(Enum(ProposalStatus), default=ProposalStatus.voting)
    published_request_id: Mapped[UUID | None] = mapped_column(Uuid, ForeignKey("service_requests.id", ondelete="SET NULL"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class GroupVote(Base):
    __tablename__ = "group_votes"
    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    proposal_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("group_proposals.id", ondelete="CASCADE"), index=True)
    user_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), index=True)
    choice: Mapped[VoteChoice] = mapped_column(Enum(VoteChoice), nullable=False)
    quantity: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, onupdate=utcnow)
    __table_args__ = (
        UniqueConstraint("proposal_id", "user_id", name="uq_proposal_vote"),
        CheckConstraint("quantity >= 0", name="ck_vote_quantity_nonnegative"),
    )


class AuditLog(Base):
    __tablename__ = "audit_logs"
    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    actor_user_id: Mapped[UUID | None] = mapped_column(Uuid, ForeignKey("users.id", ondelete="SET NULL"), index=True)
    action: Mapped[str] = mapped_column(String(120), index=True)
    entity_type: Mapped[str] = mapped_column(String(80))
    entity_id: Mapped[str] = mapped_column(String(80))
    detail: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, index=True)
