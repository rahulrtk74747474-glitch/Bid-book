from __future__ import annotations

import asyncio
import time
from collections import defaultdict
from dataclasses import dataclass

from fastapi import Request
from redis.asyncio import Redis

from .config import settings


@dataclass(frozen=True)
class RateLimitDecision:
    allowed: bool
    remaining: int
    retry_after_seconds: int


class RateLimiter:
    def __init__(self) -> None:
        self._redis: Redis | None = Redis.from_url(settings.redis_url, decode_responses=True) if settings.redis_url else None
        self._local: dict[str, list[float]] = defaultdict(list)
        self._lock = asyncio.Lock()

    async def close(self) -> None:
        if self._redis is not None:
            await self._redis.aclose()

    async def ping(self) -> bool:
        if self._redis is None:
            return settings.environment != "production"
        try:
            return bool(await self._redis.ping())
        except Exception:
            return False

    async def check(self, key: str, *, limit: int, window_seconds: int = 60) -> RateLimitDecision:
        if self._redis is not None:
            try:
                bucket = f"bidbook:rl:{window_seconds}:{key}:{int(time.time()) // window_seconds}"
                pipeline = self._redis.pipeline(transaction=True)
                pipeline.incr(bucket)
                pipeline.expire(bucket, window_seconds + 5)
                current, _ = await pipeline.execute()
                current_int = int(current)
                remaining = max(0, limit - current_int)
                return RateLimitDecision(
                    allowed=current_int <= limit,
                    remaining=remaining,
                    retry_after_seconds=window_seconds,
                )
            except Exception:
                if settings.environment == "production":
                    # Fail closed for abusive traffic when the distributed limiter is unavailable.
                    return RateLimitDecision(False, 0, 5)

        now = time.monotonic()
        cutoff = now - window_seconds
        async with self._lock:
            history = [stamp for stamp in self._local[key] if stamp >= cutoff]
            if len(history) >= limit:
                self._local[key] = history
                retry = max(1, int(window_seconds - (now - history[0])))
                return RateLimitDecision(False, 0, retry)
            history.append(now)
            self._local[key] = history
            return RateLimitDecision(True, max(0, limit - len(history)), window_seconds)


def client_ip(request: Request) -> str:
    if settings.trust_proxy_headers:
        forwarded = request.headers.get("x-forwarded-for")
        if forwarded:
            return forwarded.split(",", 1)[0].strip()
    return request.client.host if request.client else "unknown"


rate_limiter = RateLimiter()
