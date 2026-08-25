from __future__ import annotations

import logging
from typing import Protocol

import httpx

from .config import settings

logger = logging.getLogger(__name__)


class SmsSender(Protocol):
    async def send_otp(self, phone: str, otp: str) -> None: ...


class DevelopmentSmsSender:
    async def send_otp(self, phone: str, otp: str) -> None:
        logger.info("Development OTP for %s: %s", phone, otp)


class HttpSmsSender:
    async def send_otp(self, phone: str, otp: str) -> None:
        message = settings.sms_template.format(otp=otp)
        try:
            async with httpx.AsyncClient(timeout=15) as client:
                response = await client.post(
                    settings.sms_http_url,
                    headers={"Authorization": f"Bearer {settings.sms_http_token}"},
                    json={
                        "to": phone,
                        "sender_id": settings.sms_sender_id,
                        "message": message,
                        "purpose": "otp",
                    },
                )
                response.raise_for_status()
        except httpx.HTTPError as exc:
            raise RuntimeError("SMS provider could not deliver the OTP") from exc


class UnconfiguredSmsSender:
    async def send_otp(self, phone: str, otp: str) -> None:
        del phone, otp
        raise RuntimeError("Production SMS provider is not configured")


def sms_sender_for_settings() -> SmsSender:
    if settings.environment in {"development", "test"} and settings.sms_provider == "development":
        return DevelopmentSmsSender()
    if settings.sms_provider == "http" and settings.sms_http_url and settings.sms_http_token:
        return HttpSmsSender()
    return UnconfiguredSmsSender()


sms_sender: SmsSender = sms_sender_for_settings()
