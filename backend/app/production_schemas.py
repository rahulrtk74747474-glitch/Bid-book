from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class ProviderExtendedUpdate(BaseModel):
    years_experience: int = Field(default=0, ge=0, le=80)
    languages: list[str] = Field(default_factory=list, max_length=30)
    skills: list[str] = Field(default_factory=list, max_length=80)
    gstin: str | None = Field(default=None, max_length=32)
    service_radius_km: int = Field(default=10, ge=1, le=250)
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    payout_account_reference: str | None = Field(default=None, max_length=180)
    payout_method_label: str | None = Field(default=None, max_length=80)
    portfolio_headline: str | None = Field(default=None, max_length=240)


class ProviderExtendedOut(BaseModel):
    provider_id: UUID
    years_experience: int
    languages: list[str]
    skills: list[str]
    gstin: str | None
    service_radius_km: int
    latitude: float | None
    longitude: float | None
    payout_configured: bool
    payout_method_label: str | None
    portfolio_headline: str | None
    updated_at: datetime


class StaffCreate(BaseModel):
    phone: str = Field(min_length=10, max_length=18)
    role: str = Field(pattern="^(owner|manager|dispatcher|technician|accountant)$")


class StaffOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    provider_id: UUID
    user_id: UUID
    role: str
    active: bool
    created_at: datetime


class AssignmentCreate(BaseModel):
    staff_user_id: UUID


class AssignmentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    booking_id: UUID
    staff_user_id: UUID
    assigned_by_user_id: UUID
    assigned_at: datetime


class NearbyServiceOut(BaseModel):
    id: UUID
    provider_id: UUID
    provider_name: str
    provider_verified: bool
    title: str
    category: str
    description: str | None
    area: str
    price_paise: int
    pricing_unit: str
    distance_km: float | None
    rating: float | None
    review_count: int
    service_radius_km: int


class AdminStepUpRequest(BaseModel):
    code: str = Field(pattern=r"^\d{6}$")


class AdminStepUpOut(BaseModel):
    token: str
    expires_in_seconds: int


class DataExportOut(BaseModel):
    generated_at: datetime
    user: dict
    provider: dict | None
    services: list[dict]
    requests: list[dict]
    bookings: list[dict]
    payments: list[dict]
    payouts: list[dict]
    reviews: list[dict]
    disputes: list[dict]
    groups: list[dict]
    notifications: list[dict]


class IdentityLaunchOut(BaseModel):
    verification_id: UUID
    provider_reference: str
    launch_url: str


class ProviderWebhookAck(BaseModel):
    accepted: bool = True
    duplicate: bool = False
