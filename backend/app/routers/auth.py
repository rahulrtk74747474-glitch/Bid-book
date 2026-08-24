from __future__ import annotations

from datetime import timedelta
from uuid import UUID

from fastapi import APIRouter, Header, HTTPException
from sqlalchemy import func, select

from ..config import settings
from ..deps import CurrentUser, Db
from ..models import OtpChallenge, Session, User
from ..schemas import AuthResult, OtpRequest, OtpRequestResult, OtpVerify, RefreshRequest, TokenPair, UserOut
from ..security import create_access_token, generate_otp, new_refresh_token, normalize_indian_phone, otp_digest, refresh_token_hash, utcnow, verify_otp_digest
from ..sms import sms_sender

router = APIRouter(prefix="/auth", tags=["auth"])


def _token_pair(user_id: UUID, session: Session, refresh_token: str) -> TokenPair:
    return TokenPair(
        access_token=create_access_token(user_id=user_id, session_id=session.id),
        refresh_token=refresh_token,
        access_expires_in_seconds=settings.access_token_minutes * 60,
    )


@router.post("/otp/request", response_model=OtpRequestResult, status_code=201)
async def request_otp(payload: OtpRequest, db: Db) -> OtpRequestResult:
    try:
        phone = normalize_indian_phone(payload.phone)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from None

    now = utcnow()
    cooldown_since = now - timedelta(seconds=settings.otp_cooldown_seconds)
    latest = await db.execute(
        select(OtpChallenge).where(OtpChallenge.phone == phone).order_by(OtpChallenge.created_at.desc()).limit(1)
    )
    latest_challenge = latest.scalar_one_or_none()
    if latest_challenge and latest_challenge.created_at > cooldown_since:
        raise HTTPException(status_code=429, detail="Please wait before requesting another OTP")

    hour_ago = now - timedelta(hours=1)
    count_result = await db.execute(
        select(func.count(OtpChallenge.id)).where(OtpChallenge.phone == phone, OtpChallenge.created_at >= hour_ago)
    )
    if int(count_result.scalar_one()) >= settings.otp_hourly_limit:
        raise HTTPException(status_code=429, detail="OTP request limit reached. Try again later")

    challenge = OtpChallenge(
        phone=phone,
        max_attempts=settings.otp_max_attempts,
        expires_at=now + timedelta(seconds=settings.otp_ttl_seconds),
    )
    db.add(challenge)
    await db.flush()
    otp = generate_otp()
    challenge.code_digest = otp_digest(challenge_id=challenge.id, phone=phone, otp=otp)
    await db.commit()
    await sms_sender.send_otp(phone, otp)

    development_otp = None
    if settings.environment != "production" and settings.expose_development_otp:
        development_otp = otp
    return OtpRequestResult(
        challenge_id=challenge.id,
        expires_in_seconds=settings.otp_ttl_seconds,
        development_otp=development_otp,
    )


@router.post("/otp/verify", response_model=AuthResult)
async def verify_otp(payload: OtpVerify, db: Db, user_agent: str | None = Header(default=None)) -> AuthResult:
    now = utcnow()
    challenge = await db.get(OtpChallenge, payload.challenge_id, with_for_update=True)
    if challenge is None:
        raise HTTPException(status_code=404, detail="OTP challenge not found")
    if challenge.consumed_at is not None:
        raise HTTPException(status_code=409, detail="OTP challenge already used")
    if challenge.expires_at <= now:
        raise HTTPException(status_code=410, detail="OTP expired")
    if challenge.attempts >= challenge.max_attempts:
        raise HTTPException(status_code=429, detail="Too many OTP attempts")
    if challenge.code_digest is None:
        raise HTTPException(status_code=409, detail="OTP challenge unavailable")

    challenge.attempts += 1
    if not verify_otp_digest(
        challenge_id=challenge.id,
        phone=challenge.phone,
        otp=payload.otp,
        digest=challenge.code_digest,
    ):
        await db.commit()
        raise HTTPException(status_code=401, detail="Incorrect OTP")

    challenge.consumed_at = now
    result = await db.execute(select(User).where(User.phone == challenge.phone))
    user = result.scalar_one_or_none()
    if user is None:
        user = User(phone=challenge.phone)
        db.add(user)
        await db.flush()

    refresh_token = new_refresh_token()
    session = Session(
        user_id=user.id,
        refresh_hash=refresh_token_hash(refresh_token),
        device_id=payload.device_id,
        user_agent=user_agent,
        expires_at=now + timedelta(days=settings.refresh_token_days),
    )
    db.add(session)
    await db.commit()
    await db.refresh(user)
    return AuthResult(
        user=UserOut.model_validate(user),
        **_token_pair(user.id, session, refresh_token).model_dump(),
    )


@router.post("/refresh", response_model=TokenPair)
async def refresh(payload: RefreshRequest, db: Db) -> TokenPair:
    now = utcnow()
    token_hash = refresh_token_hash(payload.refresh_token)
    result = await db.execute(select(Session).where(Session.refresh_hash == token_hash).with_for_update())
    session = result.scalar_one_or_none()
    if session is None or session.revoked_at is not None or session.expires_at <= now:
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    refresh_token = new_refresh_token()
    session.refresh_hash = refresh_token_hash(refresh_token)
    session.last_used_at = now
    await db.commit()
    return _token_pair(session.user_id, session, refresh_token)


@router.post("/logout", status_code=204)
async def logout(payload: RefreshRequest, db: Db) -> None:
    token_hash = refresh_token_hash(payload.refresh_token)
    result = await db.execute(select(Session).where(Session.refresh_hash == token_hash).with_for_update())
    session = result.scalar_one_or_none()
    if session is not None and session.revoked_at is None:
        session.revoked_at = utcnow()
        await db.commit()


@router.get("/me", response_model=UserOut)
async def me(user: CurrentUser) -> UserOut:
    return UserOut.model_validate(user)
