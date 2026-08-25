from __future__ import annotations

from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class Model(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class PushTokenUpsert(Model):
    device_id: str = Field(min_length=4, max_length=200)
    platform: Literal["android", "ios"]
    token: str = Field(min_length=16, max_length=512)


class PushDeviceOut(Model):
    id: UUID
    device_id: str
    platform: str
    active: bool
    updated_at: datetime


class NotificationOut(Model):
    id: UUID
    kind: str
    title: str
    body: str
    entity_type: str | None
    entity_id: str | None
    read_at: datetime | None
    created_at: datetime


class UnreadCountOut(Model):
    count: int


class MessageCreate(Model):
    body: str = Field(min_length=1, max_length=4000)


class MessageOut(Model):
    id: UUID
    conversation_id: UUID
    sender_user_id: UUID
    body: str
    created_at: datetime


class ChatThreadOut(Model):
    id: UUID
    booking_id: UUID | None
    request_id: UUID | None
    counterpart_user_id: UUID
    counterpart_name: str
    last_message: str | None
    last_message_at: datetime | None
    unread_count: int
    created_at: datetime
