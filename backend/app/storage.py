from __future__ import annotations

import secrets
from dataclasses import dataclass

from .config import settings


@dataclass(frozen=True)
class UploadIntent:
    object_key: str
    upload_url: str
    public_url: str | None


class StorageAdapter:
    async def create_upload_intent(self, *, user_id: str, content_type: str) -> UploadIntent:
        suffix = content_type.split("/")[-1].replace("+", "_")
        object_key = f"uploads/{user_id}/{secrets.token_urlsafe(18)}.{suffix}"
        if settings.environment in {"development", "test"}:
            return UploadIntent(
                object_key=object_key,
                upload_url=f"development://{object_key}",
                public_url=None,
            )
        if not settings.storage_upload_base_url:
            raise RuntimeError("Production object-storage upload adapter is not configured")
        base = settings.storage_upload_base_url.rstrip("/")
        public = settings.storage_public_base_url.rstrip("/") if settings.storage_public_base_url else None
        return UploadIntent(
            object_key=object_key,
            upload_url=f"{base}/{object_key}",
            public_url=f"{public}/{object_key}" if public else None,
        )


storage_adapter = StorageAdapter()
