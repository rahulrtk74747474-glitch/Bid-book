from __future__ import annotations

import enum
from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import CheckConstraint, DateTime, Enum, ForeignKey, Index, Integer, String, Text, UniqueConstraint, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from .database import Base
from .security import utcnow


class VerificationMethod(str, enum.Enum):
    aadhaar_offline = "aadhaar_offline"
    government_id = "government_id"
    business = "business"


class VerificationStatus(str, enum.Enum):
    pending = "pending"
    verified = "verified"
    rejected = "rejected"
    expired = "expired"


class PaymentStatus(str, enum.Enum):
    created = "created"
    captured = "captured"
    failed = "failed"
    partially_refunded = "partially_refunded"
    refunded = "refunded"


class PayoutStatus(str, enum.Enum):
    pending = "pending"
    eligible = "eligible"
    processing = "processing"
    paid = "paid"
    held = "held"
    cancelled = "cancelled"


class RefundStatus(str, enum.Enum):
    pending = "pending"
    completed = "completed"
    failed = "failed"


class DisputeStatus(str, enum.Enum):
    open = "open"
    under_review = "under_review"
    resolved = "resolved"
    closed = "closed"


class RiskSignalStatus(str, enum.Enum):
    open = "open"
    reviewed = "reviewed"
    dismissed = "dismissed"


class IdentityVerification(Base):
    __tablename__ = "identity_verifications"
    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), index=True)
    method: Mapped[VerificationMethod] = mapped_column(Enum(VerificationMethod), nullable=False)
    status: Mapped[VerificationStatus] = mapped_column(Enum(VerificationStatus), default=VerificationStatus.pending, index=True)
    provider_name: Mapped[str] = mapped_column(String(80), default="external", nullable=False)
    provider_reference: Mapped[str] = mapped_column(String(160), unique=True, nullable=False)
    failure_reason: Mapped[str | None] = mapped_column(String(240))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, index=True)
    verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class Payment(Base):
    __tablename__ = "payments"
    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    booking_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("bookings.id", ondelete="CASCADE"), unique=True, index=True)
    customer_user_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("users.id"), index=True)
    provider_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("provider_profiles.id"), index=True)
    amount_paise: Mapped[int] = mapped_column(Integer, nullable=False)
    platform_fee_paise: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    refunded_paise: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    currency: Mapped[str] = mapped_column(String(3), default="INR", nullable=False)
    gateway: Mapped[str] = mapped_column(String(60), nullable=False)
    gateway_reference: Mapped[str] = mapped_column(String(160), unique=True, nullable=False)
    status: Mapped[PaymentStatus] = mapped_column(Enum(PaymentStatus), default=PaymentStatus.created, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, index=True)
    captured_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    __table_args__ = (
        CheckConstraint("amount_paise >= 0", name="ck_payment_amount_nonnegative"),
        CheckConstraint("platform_fee_paise >= 0", name="ck_payment_fee_nonnegative"),
        CheckConstraint("refunded_paise >= 0", name="ck_payment_refund_nonnegative"),
    )


class ProviderPayout(Base):
    __tablename__ = "provider_payouts"
    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    payment_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("payments.id", ondelete="CASCADE"), unique=True, index=True)
    provider_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("provider_profiles.id"), index=True)
    amount_paise: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[PayoutStatus] = mapped_column(Enum(PayoutStatus), default=PayoutStatus.pending, index=True)
    hold_reason: Mapped[str | None] = mapped_column(String(240))
    gateway_reference: Mapped[str | None] = mapped_column(String(160), unique=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    eligible_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    paid_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    __table_args__ = (CheckConstraint("amount_paise >= 0", name="ck_payout_amount_nonnegative"),)


class Dispute(Base):
    __tablename__ = "disputes"
    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    booking_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("bookings.id", ondelete="CASCADE"), index=True)
    opened_by_user_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("users.id"), index=True)
    against_user_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("users.id"), index=True)
    category: Mapped[str] = mapped_column(String(80), nullable=False)
    summary: Mapped[str] = mapped_column(Text, nullable=False)
    requested_refund_paise: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    status: Mapped[DisputeStatus] = mapped_column(Enum(DisputeStatus), default=DisputeStatus.open, index=True)
    resolution: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, index=True)
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    __table_args__ = (CheckConstraint("requested_refund_paise >= 0", name="ck_dispute_refund_nonnegative"),)


class Refund(Base):
    __tablename__ = "refunds"
    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    payment_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("payments.id", ondelete="CASCADE"), index=True)
    dispute_id: Mapped[UUID | None] = mapped_column(Uuid, ForeignKey("disputes.id", ondelete="SET NULL"), index=True)
    amount_paise: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[RefundStatus] = mapped_column(Enum(RefundStatus), default=RefundStatus.pending, index=True)
    gateway_reference: Mapped[str | None] = mapped_column(String(160), unique=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    __table_args__ = (CheckConstraint("amount_paise > 0", name="ck_refund_amount_positive"),)


class Review(Base):
    __tablename__ = "reviews"
    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    booking_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("bookings.id", ondelete="CASCADE"), index=True)
    reviewer_user_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("users.id"), index=True)
    subject_user_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("users.id"), index=True)
    subject_provider_id: Mapped[UUID | None] = mapped_column(Uuid, ForeignKey("provider_profiles.id"), index=True)
    rating: Mapped[int] = mapped_column(Integer, nullable=False)
    comment: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, index=True)
    __table_args__ = (
        UniqueConstraint("booking_id", "reviewer_user_id", "subject_user_id", name="uq_booking_review_party"),
        CheckConstraint("rating >= 1 AND rating <= 5", name="ck_review_rating_range"),
    )


class RiskSignal(Base):
    __tablename__ = "risk_signals"
    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    entity_type: Mapped[str] = mapped_column(String(60), index=True)
    entity_id: Mapped[str] = mapped_column(String(80), index=True)
    kind: Mapped[str] = mapped_column(String(100), index=True)
    score: Mapped[int] = mapped_column(Integer, nullable=False)
    detail: Mapped[str | None] = mapped_column(Text)
    status: Mapped[RiskSignalStatus] = mapped_column(Enum(RiskSignalStatus), default=RiskSignalStatus.open, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, index=True)
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    __table_args__ = (
        CheckConstraint("score >= 0 AND score <= 100", name="ck_risk_score_range"),
        Index("ix_risk_entity", "entity_type", "entity_id", "created_at"),
    )
