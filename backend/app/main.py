from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import settings
from .database import create_tables_for_dev
from .routers import auth, communications, groups, marketplace, trust


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings.validate()
    if settings.auto_create_tables:
        await create_tables_for_dev()
    yield


app = FastAPI(title=settings.app_name, version="0.4.0", lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost", "http://127.0.0.1"],
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
)
app.include_router(auth.router, prefix="/v1")
app.include_router(marketplace.router, prefix="/v1")
app.include_router(groups.router, prefix="/v1")
app.include_router(communications.router, prefix="/v1")
app.include_router(trust.router, prefix="/v1")


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}
