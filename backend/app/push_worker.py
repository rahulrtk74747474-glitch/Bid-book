from __future__ import annotations

import asyncio
import logging

import firebase_admin
from firebase_admin import credentials, messaging
from sqlalchemy import select

from .communication_models import Notification, PushDevice, PushOutbox
from .config import settings
from .database import SessionFactory

logger = logging.getLogger("bidbook.push")


def _ensure_firebase() -> None:
    if firebase_admin._apps:  # type: ignore[attr-defined]
        return
    if not settings.firebase_credentials_file:
        raise RuntimeError("FIREBASE_CREDENTIALS_FILE is not configured")
    firebase_admin.initialize_app(credentials.Certificate(settings.firebase_credentials_file))


def _send(device: PushDevice, notification: Notification) -> None:
    data: dict[str, str] = {"kind": notification.kind, "notification_id": str(notification.id)}
    if notification.entity_type:
        data["entity_type"] = notification.entity_type
    if notification.entity_id:
        data["entity_id"] = notification.entity_id
    message = messaging.Message(
        token=device.token,
        notification=messaging.Notification(title=notification.title, body=notification.body),
        data=data,
        android=messaging.AndroidConfig(priority="high"),
        apns=messaging.APNSConfig(headers={"apns-priority": "10"}),
    )
    messaging.send(message)


async def deliver_once() -> int:
    _ensure_firebase()
    delivered = 0
    async with SessionFactory() as db:
        result = await db.execute(
            select(PushOutbox, PushDevice, Notification)
            .join(PushDevice, PushDevice.id == PushOutbox.push_device_id)
            .join(Notification, Notification.id == PushOutbox.notification_id)
            .where(PushOutbox.status == "pending", PushDevice.active.is_(True))
            .order_by(PushOutbox.created_at.asc())
            .limit(settings.push_batch_size)
            .with_for_update(skip_locked=True)
        )
        rows = result.all()
        for outbox, device, notification in rows:
            outbox.attempts += 1
            try:
                await asyncio.to_thread(_send, device, notification)
                outbox.status = "sent"
                outbox.last_error = None
                delivered += 1
            except Exception as exc:  # Firebase SDK has multiple provider exception types.
                outbox.last_error = str(exc)[:2000]
                if outbox.attempts >= 5:
                    outbox.status = "failed"
                logger.warning("Push delivery failed for outbox=%s: %s", outbox.id, exc)
        await db.commit()
    return delivered


async def run_forever() -> None:
    if settings.environment == "production" and not settings.firebase_credentials_file:
        raise RuntimeError("Production push worker requires FIREBASE_CREDENTIALS_FILE")
    while True:
        try:
            await deliver_once()
        except Exception:
            logger.exception("Push worker iteration failed")
        await asyncio.sleep(settings.push_poll_seconds)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    asyncio.run(run_forever())
