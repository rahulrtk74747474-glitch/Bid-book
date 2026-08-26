from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from .models import BookingStatus, GroupRole, PricingUnit, ProposalStatus, ProviderKind, RequestStatus, VoteChoice


class Model(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class Message(Model):
    message: str


class OtpRequest(Model):
    phone: str = Field(min_length=8, max_length=20)


class OtpRequestResult(Model):
    challenge_id: UUID
    expires_in_seconds: int
    development_otp: str | None = None


class OtpVerify(Model):
    challenge_id: UUID
    otp: str = Field(min_length=6, max_length=6)
    device_id: str | None = Field(default=None, max_length=200)


class EmailRegister(Model):
    display_name: str = Field(min_length=2, max_length=120)
    email: str = Field(min_length=5, max_length=320)
    password: str = Field(min_length=8, max_length=128)
    device_id: str | None = Field(default=None, max_length=200)


class EmailLogin(Model):
    email: str = Field(min_length=5, max_length=320)
    password: str = Field(min_length=1, max_length=128)
    device_id: str | None = Field(default=None, max_length=200)


class GoogleLogin(Model):
    id_token: str = Field(min_length=20, max_length=10000)
    device_id: str | None = Field(default=None, max_length=200)


class RefreshRequest(Model):
    refresh_token: str = Field(min_length=32)


class TokenPair(Model):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    access_expires_in_seconds: int


class UserOut(Model):
    id: UUID
    phone: str | None
    email: str | None
    display_name: str | None
    avatar_url: str | None
    phone_verified: bool
    email_verified: bool
    identity_verified: bool
    is_admin: bool


class AuthResult(TokenPair):
    user: UserOut


class ProviderUpsert(Model):
    kind: ProviderKind
    display_name: str = Field(min_length=2, max_length=140)
    service_area: str = Field(min_length=2, max_length=180)
    bio: str | None = Field(default=None, max_length=2000)


class ProviderOut(Model):
    id: UUID
    user_id: UUID
    kind: ProviderKind
    display_name: str
    service_area: str
    bio: str | None
    active: bool


class ServiceCreate(Model):
    title: str = Field(min_length=2, max_length=160)
    category: str = Field(min_length=2, max_length=100)
    description: str = Field(min_length=2, max_length=5000)
    area: str = Field(min_length=2, max_length=180)
    price_paise: int = Field(ge=0)
    pricing_unit: PricingUnit


class ServiceOut(ServiceCreate):
    id: UUID
    provider_id: UUID
    active: bool
    created_at: datetime
    cover_photo_url: str | None = None


class RequestCreate(Model):
    title: str = Field(min_length=2, max_length=180)
    category: str = Field(min_length=2, max_length=100)
    description: str = Field(min_length=2, max_length=5000)
    area: str = Field(min_length=2, max_length=180)
    requested_for: datetime


class RequestOut(RequestCreate):
    id: UUID
    created_by_user_id: UUID
    group_id: UUID | None
    status: RequestStatus
    accepted_bid_event_id: UUID | None
    booking_id: UUID | None
    created_at: datetime
    cover_photo_url: str | None = None


class BidCreate(Model):
    amount_paise: int = Field(gt=0)
    note: str | None = Field(default=None, max_length=2000)


class BidOut(Model):
    id: UUID
    request_id: UUID
    provider_id: UUID
    amount_paise: int
    note: str | None
    previous_bid_event_id: UUID | None
    submitted_at: datetime
    is_current_offer: bool = False


class DirectBookingCreate(Model):
    scheduled_for: datetime
    area: str = Field(min_length=2, max_length=180)


class BookingOut(Model):
    id: UUID
    customer_user_id: UUID
    provider_id: UUID
    service_listing_id: UUID | None
    request_id: UUID | None
    accepted_bid_event_id: UUID | None
    agreed_amount_paise: int
    scheduled_for: datetime
    area: str
    status: BookingStatus
    created_at: datetime


class GroupCreate(Model):
    name: str = Field(min_length=2, max_length=160)
    area: str = Field(min_length=2, max_length=180)


class GroupJoin(Model):
    invite_code: str = Field(min_length=4, max_length=16)


class GroupOut(Model):
    id: UUID
    name: str
    area: str
    owner_user_id: UUID
    invite_code: str
    created_at: datetime


class MemberOut(Model):
    id: UUID
    group_id: UUID
    user_id: UUID
    role: GroupRole
    joined_at: datetime


class ProposalCreate(Model):
    title: str = Field(min_length=2, max_length=180)
    category: str = Field(min_length=2, max_length=100)
    description: str = Field(min_length=2, max_length=5000)
    preferred_for: datetime


class ProposalOut(Model):
    id: UUID
    group_id: UUID
    created_by_user_id: UUID
    title: str
    category: str
    description: str
    preferred_for: datetime
    status: ProposalStatus
    published_request_id: UUID | None
    created_at: datetime


class VoteUpsert(Model):
    choice: VoteChoice
    quantity: int = Field(default=1, ge=0, le=100)


class VoteOut(Model):
    id: UUID
    proposal_id: UUID
    user_id: UUID
    choice: VoteChoice
    quantity: int
    updated_at: datetime


class ProposalSummary(Model):
    accept_count: int
    reject_count: int
    maybe_count: int
    accepted_quantity: int
