from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from .trust_models import (
    DisputeStatus,
    PaymentStatus,
    PayoutStatus,
    RefundStatus,
    VerificationMethod,
    VerificationStatus,
)


class IdentityVerificationCreate(BaseModel):
    method: VerificationMethod


class IdentityVerificationOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    user_id: UUID
    method: VerificationMethod
    status: VerificationStatus
    provider_name: str
    provider_reference: str
    failure_reason: str | None
    created_at: datetime
    verified_at: datetime | None


class PaymentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    booking_id: UUID
    customer_user_id: UUID
    provider_id: UUID
    amount_paise: int
    platform_fee_paise: int
    refunded_paise: int
    currency: str
    gateway: str
    gateway_reference: str
    status: PaymentStatus
    created_at: datetime
    captured_at: datetime | None


class PayoutOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    payment_id: UUID
    provider_id: UUID
    amount_paise: int
    status: PayoutStatus
    hold_reason: str | None
    created_at: datetime
    eligible_at: datetime | None
    paid_at: datetime | None


class BookingTrustOut(BaseModel):
    payment: PaymentOut | None
    payout: PayoutOut | None
    can_pay: bool
    can_start: bool
    can_complete: bool
    can_review: bool
    open_dispute_count: int


class ReviewCreate(BaseModel):
    rating: int = Field(ge=1, le=5)
    comment: str | None = Field(default=None, max_length=2000)


class ReviewOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    booking_id: UUID
    reviewer_user_id: UUID
    subject_user_id: UUID
    subject_provider_id: UUID | None
    rating: int
    comment: str | None
    created_at: datetime


class ReviewSummary(BaseModel):
    count: int
    average_rating: float | None


class DisputeCreate(BaseModel):
    category: str = Field(min_length=2, max_length=80)
    summary: str = Field(min_length=10, max_length=4000)
    requested_refund_paise: int = Field(default=0, ge=0)


class DisputeOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    booking_id: UUID
    opened_by_user_id: UUID
    against_user_id: UUID
    category: str
    summary: str
    requested_refund_paise: int
    status: DisputeStatus
    resolution: str | None
    created_at: datetime
    resolved_at: datetime | None


class DevelopmentDisputeResolution(BaseModel):
    outcome: str = Field(pattern="^(release|refund)$")
    refund_paise: int = Field(default=0, ge=0)
    note: str = Field(default="Development resolution", min_length=2, max_length=1000)


class RefundOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    payment_id: UUID
    dispute_id: UUID | None
    amount_paise: int
    status: RefundStatus
    gateway_reference: str | None
    created_at: datetime
    completed_at: datetime | None


class TrustOverview(BaseModel):
    identity_verified: bool
    latest_verification: IdentityVerificationOut | None
    payments_count: int
    payouts_count: int
    open_disputes_count: int
