from __future__ import annotations

from collections.abc import Iterable
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from .communication_models import Notification, PushDevice, PushOutbox


async def notify_user(
    db: AsyncSession,
    *,
    user_id: UUID,
    kind: str,
    title: str,
    body: str,
    entity_type: str | None = None,
    entity_id: str | None = None,
) -> Notification:
    notification = Notification(
        user_id=user_id,
        kind=kind,
        title=title,
        body=body,
        entity_type=entity_type,
        entity_id=entity_id,
    )
    db.add(notification)
    await db.flush()

    devices = await db.execute(
        select(PushDevice).where(PushDevice.user_id == user_id, PushDevice.active.is_(True))
    )
    for device in devices.scalars().all():
        db.add(PushOutbox(notification_id=notification.id, push_device_id=device.id))
    return notification


async def notify_many(
    db: AsyncSession,
    *,
    user_ids: Iterable[UUID],
    kind: str,
    title: str,
    body: str,
    entity_type: str | None = None,
    entity_id: str | None = None,
    exclude_user_id: UUID | None = None,
) -> None:
    seen: set[UUID] = set()
    for user_id in user_ids:
        if user_id in seen or user_id == exclude_user_id:
            continue
        seen.add(user_id)
        await notify_user(
            db,
            user_id=user_id,
            kind=kind,
            title=title,
            body=body,
            entity_type=entity_type,
            entity_id=entity_id,
        )
