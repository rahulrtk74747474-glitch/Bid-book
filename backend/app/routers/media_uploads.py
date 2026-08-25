from __future__ import annotations

import asyncio
import os
from pathlib import Path
from uuid import UUID

from fastapi import APIRouter, Header, HTTPException, Request
from fastapi.responses import FileResponse, RedirectResponse
from sqlalchemy import select

from ..config import settings
from ..deps import CurrentUser, Db
from ..ops_models import MediaAttachment, MediaStatus
from ..ops_schemas import MediaOut
from ..security import utcnow

router = APIRouter(prefix="/ops/media", tags=["media"])

_PUBLIC_ENTITY_TYPES = {"profile", "provider", "service", "request"}
_PUBLIC_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp"}


def _dev_root() -> Path:
    return Path(os.getenv("BIDBOOK_DEV_MEDIA_DIR", ".bidbook-media")).resolve()


def _dev_path(object_key: str) -> Path:
    root = _dev_root()
    path = (root / object_key).resolve()
    if path != root and root not in path.parents:
        raise RuntimeError("Unsafe media object path")
    return path


def _public_path(media_id: UUID) -> str:
    return f"/v1/ops/media/public/{media_id}"


@router.put("/{media_id}/content", response_model=MediaOut)
async def upload_development_media(
    media_id: UUID,
    request: Request,
    db: Db,
    user: CurrentUser,
    content_type: str | None = Header(default=None, alias="Content-Type"),
) -> MediaOut:
    if settings.environment == "production":
        raise HTTPException(status_code=409, detail="Use the signed object-storage upload URL in production")

    result = await db.execute(
        select(MediaAttachment)
        .where(MediaAttachment.id == media_id, MediaAttachment.owner_user_id == user.id)
        .with_for_update()
    )
    media = result.scalar_one_or_none()
    if media is None:
        raise HTTPException(status_code=404, detail="Media attachment not found")
    if media.status in {MediaStatus.quarantined, MediaStatus.deleted}:
        raise HTTPException(status_code=409, detail="Media attachment cannot be uploaded")
    if content_type and content_type.split(";", 1)[0].strip().lower() != media.content_type.lower():
        raise HTTPException(status_code=422, detail="Uploaded content type does not match the media intent")

    body = await request.body()
    if len(body) != media.size_bytes:
        raise HTTPException(status_code=422, detail="Uploaded file size does not match the media intent")

    path = _dev_path(media.object_key)

    def _write() -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(body)

    await asyncio.to_thread(_write)
    media.status = MediaStatus.ready
    media.ready_at = utcnow()
    media.public_url = _public_path(media.id)
    await db.commit()
    await db.refresh(media)
    return MediaOut.model_validate(media)


@router.get("/gallery/{entity_type}/{entity_id}", response_model=list[str])
async def public_gallery(entity_type: str, entity_id: str, db: Db) -> list[str]:
    if entity_type not in _PUBLIC_ENTITY_TYPES:
        raise HTTPException(status_code=404, detail="Gallery not found")
    result = await db.execute(
        select(MediaAttachment)
        .where(
            MediaAttachment.entity_type == entity_type,
            MediaAttachment.entity_id == entity_id,
            MediaAttachment.status == MediaStatus.ready,
            MediaAttachment.content_type.in_(_PUBLIC_IMAGE_TYPES),
        )
        .order_by(MediaAttachment.created_at.asc())
    )
    return [item.public_url or _public_path(item.id) for item in result.scalars().all()]


@router.get("/public/{media_id}")
async def public_media(media_id: UUID, db: Db):
    media = await db.get(MediaAttachment, media_id)
    if (
        media is None
        or media.entity_type not in _PUBLIC_ENTITY_TYPES
        or media.status != MediaStatus.ready
        or media.content_type not in _PUBLIC_IMAGE_TYPES
    ):
        raise HTTPException(status_code=404, detail="Media not found")

    if settings.environment == "production":
        if media.public_url and media.public_url.startswith(("https://", "http://")):
            return RedirectResponse(media.public_url, status_code=302)
        raise HTTPException(status_code=404, detail="Public media URL is unavailable")

    path = _dev_path(media.object_key)
    if not path.is_file():
        raise HTTPException(status_code=404, detail="Media file not found")
    return FileResponse(path, media_type=media.content_type, filename=path.name)
