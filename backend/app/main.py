from __future__ import annotations

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from .config import settings
from .database import create_tables_for_dev
from .observability import ProductionGuardMiddleware
from .rate_limit import rate_limiter
from .routers import (
    auth,
    communications,
    groups,
    health,
    marketplace,
    media_production,
    operations,
    production,
    secure_booking,
    trust,
    webhooks,
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    del app
    settings.validate()
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
    )
    if settings.auto_create_tables:
        await create_tables_for_dev()
    yield
    await rate_limiter.close()


app = FastAPI(
    title=settings.app_name,
    version="0.6.0",
    lifespan=lifespan,
    docs_url="/docs" if settings.environment != "production" else None,
    redoc_url="/redoc" if settings.environment != "production" else None,
)
app.add_middleware(ProductionGuardMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE"],
    allow_headers=["Authorization", "Content-Type", "X-Admin-Stepup", "X-Request-ID"],
)


@app.middleware("http")
async def retire_unsafe_legacy_paths(request: Request, call_next):
    path = request.url.path
    if request.method == "POST" and path.startswith("/v1/trust/bookings/") and path.endswith("/start"):
        return JSONResponse(
            status_code=410,
            content={"detail": "Use the start-code protected booking start endpoint."},
        )
    if (
        settings.environment == "production"
        and request.method == "POST"
        and path.startswith("/v1/ops/media/")
        and path.endswith("/complete")
    ):
        return JSONResponse(
            status_code=410,
            content={"detail": "Use the verified production media-completion endpoint."},
        )
    return await call_next(request)


app.include_router(auth.router, prefix="/v1")
app.include_router(marketplace.router, prefix="/v1")
app.include_router(groups.router, prefix="/v1")
app.include_router(communications.router, prefix="/v1")
app.include_router(trust.router, prefix="/v1")
app.include_router(operations.router, prefix="/v1")
app.include_router(secure_booking.router, prefix="/v1")
app.include_router(production.router, prefix="/v1")
app.include_router(media_production.router, prefix="/v1")
app.include_router(webhooks.router)
app.include_router(health.router)


@app.get("/health")
async def health_legacy() -> dict[str, str]:
    return {"status": "ok"}
