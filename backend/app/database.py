from __future__ import annotations

from collections.abc import AsyncIterator

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase
from sqlalchemy.pool import NullPool

from .config import settings


class Base(DeclarativeBase):
    pass


engine_options: dict[str, object] = {
    "pool_pre_ping": True,
    "echo": False,
}
# Starlette TestClient creates a fresh event loop per context. asyncpg connections
# are loop-bound, so tests use NullPool to prevent a connection from one loop
# being reused by a later test. Production/development retain normal pooling.
if settings.environment == "test":
    engine_options["poolclass"] = NullPool

engine = create_async_engine(settings.database_url, **engine_options)
SessionFactory = async_sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)


async def get_db() -> AsyncIterator[AsyncSession]:
    async with SessionFactory() as session:
        yield session


async def create_tables_for_dev() -> None:
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
