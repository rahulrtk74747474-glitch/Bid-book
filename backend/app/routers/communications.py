from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import func, or_, select

from ..communication_models import ChatMessage, Conversation, ConversationParticipant, Notification, PushDevice
from ..communication_schemas import (
    ChatThreadOut,
    MessageCreate,
    MessageOut,
    NotificationOut,
    PushDeviceOut,
    PushTokenUpsert,
    UnreadCountOut,
)
from ..deps import CurrentUser, Db
from ..models import Booking, ProviderProfile, User
from ..notifications import notify_user
from ..security import utcnow

router = APIRouter(prefix="/communications", tags=["communications"])


async def _participant(db: Db, conversation_id: UUID, user_id: UUID) -> ConversationParticipant:
    result = await db.execute(
        select(ConversationParticipant).where(
            ConversationParticipant.conversation_id == conversation_id,
            ConversationParticipant.user_id == user_id,
        )
    )
    participant = result.scalar_one_or_none()
    if participant is None:
        raise HTTPException(status_code=403, detail="You are not a participant in this conversation")
    return participant


@router.put("/push-token", response_model=PushDeviceOut)
async def register_push_token(payload: PushTokenUpsert, db: Db, user: CurrentUser) -> PushDeviceOut:
    existing_result = await db.execute(select(PushDevice).where(PushDevice.token == payload.token))
    existing = existing_result.scalar_one_or_none()
    if existing is None:
        by_device = await db.execute(
            select(PushDevice).where(PushDevice.user_id == user.id, PushDevice.device_id == payload.device_id)
        )
        existing = by_device.scalar_one_or_none()
    if existing is None:
        existing = PushDevice(user_id=user.id, **payload.model_dump())
        db.add(existing)
    else:
        existing.user_id = user.id
        existing.device_id = payload.device_id
        existing.platform = payload.platform
        existing.token = payload.token
        existing.active = True
        existing.updated_at = utcnow()
    await db.commit()
    await db.refresh(existing)
    return PushDeviceOut.model_validate(existing)


@router.get("/notifications", response_model=list[NotificationOut])
async def list_notifications(
    db: Db,
    user: CurrentUser,
    unread_only: bool = False,
    limit: int = Query(default=100, ge=1, le=200),
) -> list[NotificationOut]:
    stmt = select(Notification).where(Notification.user_id == user.id)
    if unread_only:
        stmt = stmt.where(Notification.read_at.is_(None))
    result = await db.execute(stmt.order_by(Notification.created_at.desc()).limit(limit))
    return [NotificationOut.model_validate(item) for item in result.scalars().all()]


@router.get("/notifications/unread-count", response_model=UnreadCountOut)
async def unread_notifications(db: Db, user: CurrentUser) -> UnreadCountOut:
    result = await db.execute(
        select(func.count(Notification.id)).where(Notification.user_id == user.id, Notification.read_at.is_(None))
    )
    return UnreadCountOut(count=int(result.scalar_one()))


@router.post("/notifications/{notification_id}/read", response_model=NotificationOut)
async def mark_notification_read(notification_id: UUID, db: Db, user: CurrentUser) -> NotificationOut:
    result = await db.execute(
        select(Notification).where(Notification.id == notification_id, Notification.user_id == user.id).with_for_update()
    )
    notification = result.scalar_one_or_none()
    if notification is None:
        raise HTTPException(status_code=404, detail="Notification not found")
    if notification.read_at is None:
        notification.read_at = utcnow()
        await db.commit()
        await db.refresh(notification)
    return NotificationOut.model_validate(notification)


@router.post("/notifications/read-all", status_code=204)
async def mark_all_notifications_read(db: Db, user: CurrentUser) -> None:
    result = await db.execute(
        select(Notification).where(Notification.user_id == user.id, Notification.read_at.is_(None)).with_for_update()
    )
    now = utcnow()
    changed = False
    for notification in result.scalars().all():
        notification.read_at = now
        changed = True
    if changed:
        await db.commit()


@router.post("/chats/from-booking/{booking_id}", response_model=ChatThreadOut)
async def chat_from_booking(booking_id: UUID, db: Db, user: CurrentUser) -> ChatThreadOut:
    booking = await db.get(Booking, booking_id)
    if booking is None:
        raise HTTPException(status_code=404, detail="Booking not found")
    provider = await db.get(ProviderProfile, booking.provider_id)
    if provider is None:
        raise HTTPException(status_code=404, detail="Provider not found")
    if user.id not in {booking.customer_user_id, provider.user_id}:
        raise HTTPException(status_code=403, detail="Only booking participants can open this chat")

    existing_result = await db.execute(select(Conversation).where(Conversation.booking_id == booking.id))
    conversation = existing_result.scalar_one_or_none()
    if conversation is None:
        conversation = Conversation(booking_id=booking.id, request_id=booking.request_id)
        db.add(conversation)
        await db.flush()
        db.add_all([
            ConversationParticipant(conversation_id=conversation.id, user_id=booking.customer_user_id),
            ConversationParticipant(conversation_id=conversation.id, user_id=provider.user_id),
        ])
        await db.commit()
        await db.refresh(conversation)
    return await _thread_out(db, conversation, user.id)


async def _thread_out(db: Db, conversation: Conversation, user_id: UUID) -> ChatThreadOut:
    people = await db.execute(
        select(ConversationParticipant.user_id).where(ConversationParticipant.conversation_id == conversation.id)
    )
    participant_ids = [row[0] for row in people.all()]
    counterpart_id = next((item for item in participant_ids if item != user_id), user_id)
    counterpart = await db.get(User, counterpart_id)
    name = counterpart.display_name if counterpart and counterpart.display_name else counterpart.phone if counterpart else "User"

    last_result = await db.execute(
        select(ChatMessage)
        .where(ChatMessage.conversation_id == conversation.id)
        .order_by(ChatMessage.created_at.desc())
        .limit(1)
    )
    last = last_result.scalar_one_or_none()
    participant = await _participant(db, conversation.id, user_id)
    unread_stmt = select(func.count(ChatMessage.id)).where(
        ChatMessage.conversation_id == conversation.id,
        ChatMessage.sender_user_id != user_id,
    )
    if participant.last_read_at is not None:
        unread_stmt = unread_stmt.where(ChatMessage.created_at > participant.last_read_at)
    unread = await db.execute(unread_stmt)
    return ChatThreadOut(
        id=conversation.id,
        booking_id=conversation.booking_id,
        request_id=conversation.request_id,
        counterpart_user_id=counterpart_id,
        counterpart_name=name,
        last_message=last.body if last else None,
        last_message_at=last.created_at if last else None,
        unread_count=int(unread.scalar_one()),
        created_at=conversation.created_at,
    )


@router.get("/chats", response_model=list[ChatThreadOut])
async def list_chats(db: Db, user: CurrentUser) -> list[ChatThreadOut]:
    result = await db.execute(
        select(Conversation)
        .join(ConversationParticipant, ConversationParticipant.conversation_id == Conversation.id)
        .where(ConversationParticipant.user_id == user.id)
        .order_by(Conversation.created_at.desc())
    )
    return [await _thread_out(db, conversation, user.id) for conversation in result.scalars().all()]


@router.get("/chats/{conversation_id}/messages", response_model=list[MessageOut])
async def list_messages(
    conversation_id: UUID,
    db: Db,
    user: CurrentUser,
    limit: int = Query(default=100, ge=1, le=200),
) -> list[MessageOut]:
    participant = await _participant(db, conversation_id, user.id)
    result = await db.execute(
        select(ChatMessage)
        .where(ChatMessage.conversation_id == conversation_id)
        .order_by(ChatMessage.created_at.asc())
        .limit(limit)
    )
    messages = list(result.scalars().all())
    participant.last_read_at = utcnow()
    await db.commit()
    return [MessageOut.model_validate(message) for message in messages]


@router.post("/chats/{conversation_id}/messages", response_model=MessageOut, status_code=201)
async def send_message(
    conversation_id: UUID,
    payload: MessageCreate,
    db: Db,
    user: CurrentUser,
) -> MessageOut:
    sender_participant = await _participant(db, conversation_id, user.id)
    body = payload.body.strip()
    if not body:
        raise HTTPException(status_code=422, detail="Message cannot be blank")

    message = ChatMessage(conversation_id=conversation_id, sender_user_id=user.id, body=body)
    db.add(message)
    await db.flush()
    sender_participant.last_read_at = message.created_at

    recipients = await db.execute(
        select(ConversationParticipant.user_id).where(
            ConversationParticipant.conversation_id == conversation_id,
            ConversationParticipant.user_id != user.id,
        )
    )
    sender_name = user.display_name or user.phone
    for recipient_id in recipients.scalars().all():
        await notify_user(
            db,
            user_id=recipient_id,
            kind="chat_message",
            title=f"New message from {sender_name}",
            body=body[:180],
            entity_type="conversation",
            entity_id=str(conversation_id),
        )
    await db.commit()
    await db.refresh(message)
    return MessageOut.model_validate(message)
