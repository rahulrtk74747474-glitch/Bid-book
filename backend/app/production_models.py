from __future__ import annotations

from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, Text, UniqueConstraint, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from .database import Base
from .security import utcnow


class ProviderExtendedProfile(Base):
    __tablename__ = "provider_extended_profiles"
    provider_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("provider_profiles.id", ondelete="CASCADE"),
        primary_key=True,
    )
    years_experience: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    languages_csv: Mapped[str] = mapped_column(Text, default="", nullable=False)
    skills_csv: Mapped[str] = mapped_column(Text, default="", nullable=False)
    gstin: Mapped[str | None] = mapped_column(String(32))
    service_radius_km: Mapped[int] = mapped_column(Integer, default=10, nullable=False)
    latitude: Mapped[float | None] = mapped_column(Float)
    longitude: Mapped[float | None] = mapped_column(Float)
    payout_account_reference: Mapped[str | None] = mapped_column(String(180))
    payout_method_label: Mapped[str | None] = mapped_column(String(80))
    portfolio_headline: Mapped[str | None] = mapped_column(String(240))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, onupdate=utcnow)


class ProviderStaff(Base):
    __tablename__ = "provider_staff"
    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    provider_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("provider_profiles.id", ondelete="CASCADE"),
        index=True,
    )
    user_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), index=True)
    role: Mapped[str] = mapped_column(String(32), nullable=False)
    active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    __table_args__ = (UniqueConstraint("provider_id", "user_id", name="uq_provider_staff_user"),)


class BookingAssignment(Base):
    __tablename__ = "booking_assignments"
    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    booking_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("bookings.id", ondelete="CASCADE"),
        unique=True,
        index=True,
    )
    staff_user_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), index=True)
    assigned_by_user_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("users.id", ondelete="CASCADE"))
    assigned_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class WebhookReceipt(Base):
    __tablename__ = "webhook_receipts"
    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    provider: Mapped[str] = mapped_column(String(40), index=True)
    event_id: Mapped[str] = mapped_column(String(180), nullable=False)
    event_type: Mapped[str] = mapped_column(String(120), index=True)
    payload_sha256: Mapped[str] = mapped_column(String(64), nullable=False)
    status: Mapped[str] = mapped_column(String(24), default="received", index=True)
    error: Mapped[str | None] = mapped_column(Text)
    received_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, index=True)
    processed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    __table_args__ = (UniqueConstraint("provider", "event_id", name="uq_webhook_provider_event"),)
