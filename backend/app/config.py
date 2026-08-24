from __future__ import annotations

import os
from dataclasses import dataclass


def _bool(name: str, default: bool = False) -> bool:
    return os.getenv(name, str(default)).strip().lower() in {"1", "true", "yes", "on"}


def _int(name: str, default: int) -> int:
    return int(os.getenv(name, str(default)))


@dataclass(frozen=True)
class Settings:
    app_name: str = os.getenv("APP_NAME", "Bid&Book API")
    environment: str = os.getenv("ENVIRONMENT", "development")
    database_url: str = os.getenv(
        "DATABASE_URL",
        "postgresql+asyncpg://bidbook:bidbook@localhost:5432/bidbook",
    )
    jwt_secret: str = os.getenv(
        "JWT_SECRET",
        "development-only-change-me-development-only-change-me",
    )
    otp_pepper: str = os.getenv(
        "OTP_PEPPER",
        "development-only-change-me-otp-pepper",
    )
    access_token_minutes: int = _int("ACCESS_TOKEN_MINUTES", 15)
    refresh_token_days: int = _int("REFRESH_TOKEN_DAYS", 30)
    otp_ttl_seconds: int = _int("OTP_TTL_SECONDS", 300)
    otp_max_attempts: int = _int("OTP_MAX_ATTEMPTS", 5)
    otp_cooldown_seconds: int = _int("OTP_COOLDOWN_SECONDS", 45)
    otp_hourly_limit: int = _int("OTP_HOURLY_LIMIT", 8)
    expose_development_otp: bool = _bool("EXPOSE_DEVELOPMENT_OTP", True)
    auto_create_tables: bool = _bool("AUTO_CREATE_TABLES", False)

    def validate(self) -> None:
        if self.environment == "production":
            if "development-only" in self.jwt_secret or len(self.jwt_secret) < 48:
                raise RuntimeError("Production JWT_SECRET must be a strong secret (48+ chars).")
            if "development-only" in self.otp_pepper or len(self.otp_pepper) < 32:
                raise RuntimeError("Production OTP_PEPPER must be a strong secret (32+ chars).")
            if self.expose_development_otp:
                raise RuntimeError("EXPOSE_DEVELOPMENT_OTP must be false in production.")


settings = Settings()
