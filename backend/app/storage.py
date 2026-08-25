from __future__ import annotations

import asyncio
import secrets
from dataclasses import dataclass

import boto3
from botocore.config import Config
from botocore.exceptions import BotoCoreError, ClientError

from .config import settings


@dataclass(frozen=True)
class UploadIntent:
    object_key: str
    upload_url: str
    public_url: str | None


@dataclass(frozen=True)
class StoredObject:
    exists: bool
    size_bytes: int | None = None
    content_type: str | None = None


class StorageAdapter:
    def _client(self):
        if settings.storage_provider != "s3":
            return None
        kwargs: dict[str, object] = {
            "service_name": "s3",
            "region_name": settings.s3_region,
            "config": Config(signature_version="s3v4"),
        }
        if settings.s3_endpoint_url:
            kwargs["endpoint_url"] = settings.s3_endpoint_url
        if settings.s3_access_key_id:
            kwargs["aws_access_key_id"] = settings.s3_access_key_id
        if settings.s3_secret_access_key:
            kwargs["aws_secret_access_key"] = settings.s3_secret_access_key
        return boto3.client(**kwargs)

    async def create_upload_intent(self, *, user_id: str, content_type: str) -> UploadIntent:
        suffix = content_type.split("/")[-1].replace("+", "_")
        object_key = f"uploads/{user_id}/{secrets.token_urlsafe(18)}.{suffix}"
        if settings.environment in {"development", "test"} and settings.storage_provider == "development":
            return UploadIntent(
                object_key=object_key,
                upload_url=f"development://{object_key}",
                public_url=None,
            )
        client = self._client()
        if client is None or not settings.s3_bucket:
            raise RuntimeError("Production S3-compatible object storage is not configured")

        def make_url() -> str:
            try:
                return client.generate_presigned_url(
                    "put_object",
                    Params={
                        "Bucket": settings.s3_bucket,
                        "Key": object_key,
                        "ContentType": content_type,
                    },
                    ExpiresIn=settings.s3_presign_seconds,
                )
            except (BotoCoreError, ClientError) as exc:
                raise RuntimeError("Could not create media upload URL") from exc

        upload_url = await asyncio.to_thread(make_url)
        public_base = settings.storage_public_base_url.rstrip("/") if settings.storage_public_base_url else None
        return UploadIntent(
            object_key=object_key,
            upload_url=upload_url,
            public_url=f"{public_base}/{object_key}" if public_base else None,
        )

    async def verify_upload(self, *, object_key: str) -> StoredObject:
        if settings.environment in {"development", "test"} and settings.storage_provider == "development":
            return StoredObject(True)
        client = self._client()
        if client is None or not settings.s3_bucket:
            raise RuntimeError("Production S3-compatible object storage is not configured")

        def head() -> StoredObject:
            try:
                response = client.head_object(Bucket=settings.s3_bucket, Key=object_key)
                return StoredObject(
                    True,
                    size_bytes=int(response.get("ContentLength", 0)),
                    content_type=response.get("ContentType"),
                )
            except ClientError as exc:
                status = int(exc.response.get("ResponseMetadata", {}).get("HTTPStatusCode", 0))
                if status == 404:
                    return StoredObject(False)
                raise RuntimeError("Could not verify uploaded media") from exc
            except BotoCoreError as exc:
                raise RuntimeError("Could not verify uploaded media") from exc

        return await asyncio.to_thread(head)


storage_adapter = StorageAdapter()
