from __future__ import annotations

from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import Boolean, DateTime, ForeignKey, Index, Integer, String, Text, UniqueConstraint, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from .database import Base
from .security import utcnow


class PushDevice(Base):
    __tablename__ = "push_devices"
    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), index=True)
    device_id: Mapped[str] = mapped_column(String(200), index=True)
    platform: Mapped[str] = mapped_column(String(16), nullable=False)
    token: Mapped[str] = mapped_column(String(512), unique=True, nullable=False)
    active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, onupdate=utcnow)
    __table_args__ = (UniqueConstraint("user_id", "device_id", name="uq_push_user_device"),)


class Notification(Base):
    __tablename__ = "notifications"
    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), index=True)
    kind: Mapped[str] = mapped_column(String(80), index=True)
    title: Mapped[str] = mapped_column(String(180), nullable=False)
    body: Mapped[str] = mapped_column(Text, nullable=False)
    entity_type: Mapped[str | None] = mapped_column(String(80))
    entity_id: Mapped[str | None] = mapped_column(String(80))
    read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, index=True)
    __table_args__ = (Index("ix_notification_user_created", "user_id", "created_at"),)


class PushOutbox(Base):
    __tablename__ = "push_outbox"
    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    notification_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("notifications.id", ondelete="CASCADE"), index=True)
    push_device_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("push_devices.id", ondelete="CASCADE"), index=True)
    status: Mapped[str] = mapped_column(String(24), default="pending", index=True)
    attempts: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    last_error: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, index=True)
    __table_args__ = (UniqueConstraint("notification_id", "push_device_id", name="uq_push_delivery"),)


class Conversation(Base):
    __tablename__ = "conversations"
    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    booking_id: Mapped[UUID | None] = mapped_column(Uuid, ForeignKey("bookings.id", ondelete="SET NULL"), unique=True, index=True)
    request_id: Mapped[UUID | None] = mapped_column(Uuid, ForeignKey("service_requests.id", ondelete="SET NULL"), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, index=True)


class ConversationParticipant(Base):
    __tablename__ = "conversation_participants"
    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    conversation_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("conversations.id", ondelete="CASCADE"), index=True)
    user_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), index=True)
    last_read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    joined_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    __table_args__ = (UniqueConstraint("conversation_id", "user_id", name="uq_conversation_participant"),)


class ChatMessage(Base):
    __tablename__ = "chat_messages"
    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    conversation_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("conversations.id", ondelete="CASCADE"), index=True)
    sender_user_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), index=True)
    body: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, index=True)
    __table_args__ = (Index("ix_chat_conversation_created", "conversation_id", "created_at"),)
