from __future__ import annotations

import json
import logging
import time
from uuid import uuid4

import jwt
from fastapi import Request
from fastapi.responses import JSONResponse, Response
from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint

from .admin_mfa import decode_admin_stepup_token
from .config import settings
from .rate_limit import client_ip, rate_limiter
from .security import decode_access_token

logger = logging.getLogger("bidbook.http")


class ProductionGuardMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        request_id = request.headers.get("x-request-id") or uuid4().hex
        started = time.perf_counter()
        path = request.url.path

        content_length = request.headers.get("content-length")
        if content_length:
            try:
                if int(content_length) > settings.request_body_max_bytes:
                    return self._json(413, "Request body is too large", request_id)
            except ValueError:
                return self._json(400, "Invalid Content-Length header", request_id)

        if path.startswith("/v1/"):
            limit = settings.auth_rate_limit_per_minute if path.startswith("/v1/auth/") else settings.global_rate_limit_per_minute
            decision = await rate_limiter.check(
                f"{client_ip(request)}:{path.split('/', 4)[1:4]}",
                limit=limit,
            )
            if not decision.allowed:
                response = self._json(429, "Too many requests. Try again shortly.", request_id)
                response.headers["Retry-After"] = str(decision.retry_after_seconds)
                return response

        if settings.environment == "production" and path.startswith("/v1/admin"):
            failure = self._validate_admin_stepup(request)
            if failure is not None:
                return self._json(401, failure, request_id)

        try:
            response = await call_next(request)
        except Exception:
            logger.exception("Unhandled request error", extra={"request_id": request_id})
            raise
        finally:
            elapsed_ms = round((time.perf_counter() - started) * 1000, 2)
            logger.info(
                json.dumps(
                    {
                        "event": "http_request",
                        "request_id": request_id,
                        "method": request.method,
                        "path": path,
                        "duration_ms": elapsed_ms,
                        "client_ip": client_ip(request),
                    },
                    separators=(",", ":"),
                )
            )

        response.headers["X-Request-ID"] = request_id
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Referrer-Policy"] = "no-referrer"
        response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
        if settings.environment == "production":
            response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
        return response

    @staticmethod
    def _validate_admin_stepup(request: Request) -> str | None:
        stepup = request.headers.get("x-admin-stepup")
        authorization = request.headers.get("authorization", "")
        if not stepup or not authorization.lower().startswith("bearer "):
            return "Admin MFA step-up is required"
        try:
            access_user_id, _ = decode_access_token(authorization.split(" ", 1)[1].strip())
            stepup_user_id = decode_admin_stepup_token(stepup)
        except (jwt.InvalidTokenError, ValueError):
            return "Admin MFA step-up is invalid or expired"
        if access_user_id != stepup_user_id:
            return "Admin MFA step-up does not match the signed-in account"
        return None

    @staticmethod
    def _json(status: int, detail: str, request_id: str) -> JSONResponse:
        response = JSONResponse(status_code=status, content={"detail": detail, "request_id": request_id})
        response.headers["X-Request-ID"] = request_id
        return response
