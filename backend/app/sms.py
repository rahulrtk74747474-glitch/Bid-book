from __future__ import annotations

import logging
from typing import Protocol

logger = logging.getLogger(__name__)


class SmsSender(Protocol):
    async def send_otp(self, phone: str, otp: str) -> None: ...


class DevelopmentSmsSender:
    async def send_otp(self, phone: str, otp: str) -> None:
        # Do not use this implementation in production. It deliberately avoids
        # external credentials so the repository never contains SMS secrets.
        logger.info("Development OTP for %s: %s", phone, otp)


sms_sender: SmsSender = DevelopmentSmsSender()
