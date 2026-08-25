from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from .ops_models import CasePriority, CaseStatus, MediaStatus, ReportStatus, WarrantyStatus
from .trust_models import DisputeStatus, PayoutStatus, RiskSignalStatus, VerificationStatus


class Model(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class SupportCaseCreate(Model):
    subject: str = Field(min_length=3, max_length=180)
    category: str = Field(min_length=2, max_length=80)
    description: str = Field(min_length=5, max_length=5000)
    priority: CasePriority = CasePriority.normal


class SupportCaseOut(Model):
    id: UUID
    user_id: UUID
    subject: str
    category: str
    description: str
    priority: CasePriority
    status: CaseStatus
    assigned_admin_user_id: UUID | None
    created_at: datetime
    updated_at: datetime


class SupportMessageCreate(Model):
    body: str = Field(min_length=1, max_length=5000)


class SupportMessageOut(Model):
    id: UUID
    case_id: UUID
    author_user_id: UUID
    body: str
    is_internal: bool
    created_at: datetime


class ReportCreate(Model):
    entity_type: str = Field(min_length=2, max_length=60)
    entity_id: str = Field(min_length=1, max_length=100)
    category: str = Field(min_length=2, max_length=80)
    summary: str = Field(min_length=5, max_length=4000)


class ReportOut(Model):
    id: UUID
    reporter_user_id: UUID
    entity_type: str
    entity_id: str
    category: str
    summary: str
    status: ReportStatus
    resolution: str | None
    created_at: datetime
    resolved_at: datetime | None


class AvailabilitySlot(Model):
    weekday: int = Field(ge=0, le=6)
    start_minute: int = Field(ge=0, lt=1440)
    end_minute: int = Field(gt=0, le=1440)
    active: bool = True


class AvailabilityOut(AvailabilitySlot):
    id: UUID
    provider_id: UUID
    updated_at: datetime


class AvailabilityReplace(Model):
    slots: list[AvailabilitySlot] = Field(max_length=28)


class MediaIntentCreate(Model):
    entity_type: str = Field(min_length=2, max_length=60)
    entity_id: str = Field(min_length=1, max_length=100)
    content_type: str = Field(pattern=r"^(image|application/pdf)/?[a-zA-Z0-9.+-]*$", max_length=120)
    size_bytes: int = Field(gt=0, le=15 * 1024 * 1024)


class MediaIntentOut(Model):
    id: UUID
    object_key: str
    upload_url: str
    public_url: str | None
    status: MediaStatus


class MediaOut(Model):
    id: UUID
    owner_user_id: UUID
    entity_type: str
    entity_id: str
    content_type: str
    size_bytes: int
    status: MediaStatus
    public_url: str | None
    created_at: datetime


class WarrantyCreate(Model):
    issue: str = Field(min_length=5, max_length=4000)


class WarrantyOut(Model):
    id: UUID
    booking_id: UUID
    customer_user_id: UUID
    provider_id: UUID
    issue: str
    status: WarrantyStatus
    resolution: str | None
    created_at: datetime
    resolved_at: datetime | None


class StartCodeOut(Model):
    booking_id: UUID
    code: str
    expires_at: datetime


class StartCodeVerify(Model):
    code: str = Field(min_length=6, max_length=6)


class AdminOverview(Model):
    users: int
    providers: int
    active_services: int
    bookings: int
    completed_bookings: int
    captured_gmv_paise: int
    platform_fees_paise: int
    open_disputes: int
    open_reports: int
    open_support_cases: int
    open_risk_signals: int
    pending_verifications: int
    pending_payouts: int


class AdminUserOut(Model):
    id: UUID
    phone: str
    display_name: str | None
    identity_verified: bool
    is_admin: bool
    is_active: bool
    suspended_at: datetime | None
    suspension_reason: str | None
    created_at: datetime


class SuspendUser(Model):
    reason: str = Field(min_length=3, max_length=500)


class VerificationDecision(Model):
    status: VerificationStatus
    reason: str | None = Field(default=None, max_length=500)


class AdminDisputeDecision(Model):
    status: DisputeStatus = DisputeStatus.resolved
    resolution: str = Field(min_length=3, max_length=4000)
    refund_paise: int = Field(default=0, ge=0)


class AdminPayoutDecision(Model):
    status: PayoutStatus


class RiskDecision(Model):
    status: RiskSignalStatus
    detail: str | None = Field(default=None, max_length=2000)


class ReportDecision(Model):
    status: ReportStatus
    resolution: str = Field(min_length=2, max_length=4000)


class SupportDecision(Model):
    status: CaseStatus
    priority: CasePriority | None = None
    assign_to_me: bool = False


class WarrantyDecision(Model):
    status: WarrantyStatus
    resolution: str = Field(min_length=2, max_length=4000)


class DiscoveryServiceOut(Model):
    id: UUID
    provider_id: UUID
    provider_user_id: UUID
    provider_name: str
    provider_verified: bool
    provider_rating: float | None
    provider_review_count: int
    title: str
    category: str
    description: str
    area: str
    price_paise: int
    pricing_unit: str
    created_at: datetime
