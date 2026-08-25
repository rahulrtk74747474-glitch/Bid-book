from __future__ import annotations

import os
from dataclasses import dataclass


def _bool(name: str, default: bool = False) -> bool:
    return os.getenv(name, str(default)).strip().lower() in {"1", "true", "yes", "on"}


def _int(name: str, default: int) -> int:
    return int(os.getenv(name, str(default)))


def _float(name: str, default: float) -> float:
    return float(os.getenv(name, str(default)))


@dataclass(frozen=True)
class Settings:
    app_name: str = os.getenv("APP_NAME", "Bid&Book API")
    environment: str = os.getenv("ENVIRONMENT", "development")
    public_api_url: str = os.getenv("PUBLIC_API_URL", "")
    database_url: str = os.getenv(
        "DATABASE_URL",
        "postgresql+asyncpg://bidbook:bidbook@localhost:5432/bidbook",
    )
    redis_url: str = os.getenv("REDIS_URL", "")
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
    admin_phones_csv: str = os.getenv("ADMIN_PHONES", "")
    admin_mfa_secret: str = os.getenv("ADMIN_MFA_SECRET", "")
    admin_stepup_minutes: int = _int("ADMIN_STEPUP_MINUTES", 10)

    cors_origins_csv: str = os.getenv(
        "CORS_ORIGINS",
        "http://localhost,http://127.0.0.1",
    )
    request_body_max_bytes: int = _int("REQUEST_BODY_MAX_BYTES", 10 * 1024 * 1024)
    global_rate_limit_per_minute: int = _int("GLOBAL_RATE_LIMIT_PER_MINUTE", 180)
    auth_rate_limit_per_minute: int = _int("AUTH_RATE_LIMIT_PER_MINUTE", 30)
    trust_proxy_headers: bool = _bool("TRUST_PROXY_HEADERS", False)

    storage_provider: str = os.getenv("STORAGE_PROVIDER", "development")
    storage_upload_base_url: str = os.getenv("STORAGE_UPLOAD_BASE_URL", "")
    storage_public_base_url: str = os.getenv("STORAGE_PUBLIC_BASE_URL", "")
    s3_bucket: str = os.getenv("S3_BUCKET", "")
    s3_region: str = os.getenv("S3_REGION", "ap-south-1")
    s3_endpoint_url: str = os.getenv("S3_ENDPOINT_URL", "")
    s3_access_key_id: str = os.getenv("S3_ACCESS_KEY_ID", "")
    s3_secret_access_key: str = os.getenv("S3_SECRET_ACCESS_KEY", "")
    s3_presign_seconds: int = _int("S3_PRESIGN_SECONDS", 900)

    sms_provider: str = os.getenv("SMS_PROVIDER", "development")
    sms_http_url: str = os.getenv("SMS_HTTP_URL", "")
    sms_http_token: str = os.getenv("SMS_HTTP_TOKEN", "")
    sms_sender_id: str = os.getenv("SMS_SENDER_ID", "BIDBOOK")
    sms_template: str = os.getenv(
        "SMS_TEMPLATE",
        "Your Bid&Book OTP is {otp}. It expires in 5 minutes.",
    )

    payment_provider: str = os.getenv("PAYMENT_PROVIDER", "development")
    razorpay_key_id: str = os.getenv("RAZORPAY_KEY_ID", "")
    razorpay_key_secret: str = os.getenv("RAZORPAY_KEY_SECRET", "")
    razorpay_webhook_secret: str = os.getenv("RAZORPAY_WEBHOOK_SECRET", "")
    platform_fee_bps: int = _int("PLATFORM_FEE_BPS", 0)

    payout_http_url: str = os.getenv("PAYOUT_HTTP_URL", "")
    payout_http_token: str = os.getenv("PAYOUT_HTTP_TOKEN", "")
    payout_webhook_secret: str = os.getenv("PAYOUT_WEBHOOK_SECRET", "")

    identity_http_url: str = os.getenv("IDENTITY_HTTP_URL", "")
    identity_http_token: str = os.getenv("IDENTITY_HTTP_TOKEN", "")
    identity_webhook_secret: str = os.getenv("IDENTITY_WEBHOOK_SECRET", "")

    firebase_credentials_file: str = os.getenv("FIREBASE_CREDENTIALS_FILE", "")
    push_batch_size: int = _int("PUSH_BATCH_SIZE", 100)
    push_poll_seconds: float = _float("PUSH_POLL_SECONDS", 2.0)

    @property
    def admin_phones(self) -> set[str]:
        return {item.strip() for item in self.admin_phones_csv.split(",") if item.strip()}

    @property
    def cors_origins(self) -> list[str]:
        return [item.strip() for item in self.cors_origins_csv.split(",") if item.strip()]

    def validate(self) -> None:
        if not 0 <= self.platform_fee_bps <= 5000:
            raise RuntimeError("PLATFORM_FEE_BPS must be between 0 and 5000.")
        if self.request_body_max_bytes < 1024:
            raise RuntimeError("REQUEST_BODY_MAX_BYTES is too small.")
        if self.global_rate_limit_per_minute < 1 or self.auth_rate_limit_per_minute < 1:
            raise RuntimeError("Rate limits must be positive.")
        if self.environment == "production":
            if "development-only" in self.jwt_secret or len(self.jwt_secret) < 48:
                raise RuntimeError("Production JWT_SECRET must be a strong secret (48+ chars).")
            if "development-only" in self.otp_pepper or len(self.otp_pepper) < 32:
                raise RuntimeError("Production OTP_PEPPER must be a strong secret (32+ chars).")
            if self.expose_development_otp:
                raise RuntimeError("EXPOSE_DEVELOPMENT_OTP must be false in production.")
            if not self.redis_url:
                raise RuntimeError("REDIS_URL is required in production for distributed rate limiting.")
            if not self.public_api_url.startswith("https://"):
                raise RuntimeError("PUBLIC_API_URL must be HTTPS in production.")
            if "*" in self.cors_origins:
                raise RuntimeError("Wildcard CORS origins are not allowed in production.")
            if self.admin_phones and len(self.admin_mfa_secret) < 16:
                raise RuntimeError("ADMIN_MFA_SECRET is required when production admin accounts are enabled.")


settings = Settings()
