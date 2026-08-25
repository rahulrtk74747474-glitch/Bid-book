from __future__ import annotations

from typing import Annotated

import jwt
from fastapi import Depends, Header, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from .database import get_db
from .models import ProviderProfile, Session, User
from .security import decode_access_token, utcnow

Db = Annotated[AsyncSession, Depends(get_db)]


async def current_user(db: Db, authorization: Annotated[str | None, Header()] = None) -> User:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing bearer token")
    token = authorization.removeprefix("Bearer ").strip()
    try:
        user_id, session_id = decode_access_token(token)
    except (jwt.InvalidTokenError, ValueError, KeyError):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid access token") from None

    session = await db.get(Session, session_id)
    if session is None or session.user_id != user_id or session.revoked_at is not None or session.expires_at <= utcnow():
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Session expired")
    user = await db.get(User, user_id)
    if user is None or not user.is_active or user.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User unavailable")
    if user.suspended_at is not None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account suspended")
    return user


CurrentUser = Annotated[User, Depends(current_user)]


async def current_admin(user: CurrentUser) -> User:
    if not user.is_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Administrator permission required")
    return user


CurrentAdmin = Annotated[User, Depends(current_admin)]


async def current_provider(db: Db, user: CurrentUser) -> ProviderProfile:
    result = await db.execute(select(ProviderProfile).where(ProviderProfile.user_id == user.id))
    provider = result.scalar_one_or_none()
    if provider is None or not provider.active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Provider profile required")
    return provider


CurrentProvider = Annotated[ProviderProfile, Depends(current_provider)]
