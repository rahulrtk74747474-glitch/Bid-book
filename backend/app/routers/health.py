from __future__ import annotations

from fastapi import APIRouter, HTTPException
from sqlalchemy import text

from ..database import SessionFactory
from ..rate_limit import rate_limiter

router = APIRouter(tags=["health"])


@router.get("/live")
async def live() -> dict[str, str]:
    return {"status": "ok"}


@router.get("/ready")
async def ready() -> dict[str, str]:
    try:
        async with SessionFactory() as db:
            await db.execute(text("SELECT 1"))
    except Exception as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
    if not await rate_limiter.ping():
        raise HTTPException(status_code=503, detail="Rate-limit store unavailable")
    return {"status": "ready"}
