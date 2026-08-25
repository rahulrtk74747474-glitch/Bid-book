from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, HTTPException
from sqlalchemy import select

from ..deps import CurrentUser, Db
from ..ops_models import MediaAttachment, MediaStatus
from ..ops_schemas import MediaOut
from ..security import utcnow
from ..storage import storage_adapter

router = APIRouter(prefix="/production/media", tags=["production-media"])


@router.post("/{media_id}/complete", response_model=MediaOut)
async def verify_and_complete_media(media_id: UUID, db: Db, user: CurrentUser) -> MediaOut:
    result = await db.execute(
        select(MediaAttachment)
        .where(MediaAttachment.id == media_id, MediaAttachment.owner_user_id == user.id)
        .with_for_update()
    )
    media = result.scalar_one_or_none()
    if media is None:
        raise HTTPException(status_code=404, detail="Media attachment not found")
    if media.status == MediaStatus.quarantined:
        raise HTTPException(status_code=409, detail="Media attachment is quarantined")
    if media.status == MediaStatus.ready:
        return MediaOut.model_validate(media)
    try:
        stored = await storage_adapter.verify_upload(object_key=media.object_key)
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    if not stored.exists:
        raise HTTPException(status_code=409, detail="Upload is not present in object storage")
    if stored.content_type and stored.content_type != media.content_type:
        raise HTTPException(status_code=409, detail="Uploaded media content type does not match the upload intent")
    if stored.size_bytes is not None:
        if stored.size_bytes <= 0:
            raise HTTPException(status_code=409, detail="Uploaded media file is empty")
        if media.size_bytes and stored.size_bytes != media.size_bytes:
            raise HTTPException(status_code=409, detail="Uploaded media size does not match the upload intent")
    media.status = MediaStatus.ready
    media.ready_at = utcnow()
    await db.commit()
    await db.refresh(media)
    return MediaOut.model_validate(media)
