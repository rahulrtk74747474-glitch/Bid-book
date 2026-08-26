from __future__ import annotations

from datetime import timedelta
from uuid import UUID

from fastapi import APIRouter, Header, HTTPException
from sqlalchemy import func, select

from ..config import settings
from ..deps import CurrentUser, Db
from ..google_identity import verify_google_token
from ..models import OtpChallenge, Session, User
from ..schemas import (
    AuthResult,
    EmailLogin,
    EmailRegister,
    GoogleLogin,
    OtpRequest,
    OtpRequestResult,
    OtpVerify,
    RefreshRequest,
    TokenPair,
    UserOut,
)
from ..security import (
    create_access_token,
    generate_otp,
    hash_password,
    new_refresh_token,
    normalize_email,
    normalize_indian_phone,
    otp_digest,
    refresh_token_hash,
    utcnow,
    verify_otp_digest,
    verify_password,
)
from ..sms import sms_sender

router = APIRouter(prefix="/auth", tags=["auth"])


def _token_pair(user_id: UUID, session: Session, refresh_token: str) -> TokenPair:
    return TokenPair(
        access_token=create_access_token(user_id=user_id, session_id=session.id),
        refresh_token=refresh_token,
        access_expires_in_seconds=settings.access_token_minutes * 60,
    )


def _ensure_account_available(user: User) -> None:
    if not user.is_active or user.deleted_at is not None:
        raise HTTPException(status_code=403, detail="Account unavailable")
    if user.suspended_at is not None:
        raise HTTPException(status_code=403, detail="Account suspended")


async def _authenticated_result(
    *,
    user: User,
    db: Db,
    device_id: str | None,
    user_agent: str | None,
) -> AuthResult:
    now = utcnow()
    refresh_token = new_refresh_token()
    session = Session(
        user_id=user.id,
        refresh_hash=refresh_token_hash(refresh_token),
        device_id=device_id,
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


@router.post("/otp/request", response_model=OtpRequestResult, status_code=201)
async def request_otp(payload: OtpRequest, db: Db) -> OtpRequestResult:
    try:
        phone = normalize_indian_phone(payload.phone)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from None

    existing_user = await db.execute(select(User).where(User.phone == phone))
    account = existing_user.scalar_one_or_none()
    if account is not None:
        _ensure_account_available(account)

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
    should_be_admin = challenge.phone in settings.admin_phones
    if user is None:
        user = User(phone=challenge.phone, phone_verified=True, is_admin=should_be_admin)
        db.add(user)
        await db.flush()
    else:
        _ensure_account_available(user)
        user.phone_verified = True
        if should_be_admin and not user.is_admin:
            user.is_admin = True

    return await _authenticated_result(
        user=user,
        db=db,
        device_id=payload.device_id,
        user_agent=user_agent,
    )


@router.post("/email/register", response_model=AuthResult, status_code=201)
async def register_email(
    payload: EmailRegister,
    db: Db,
    user_agent: str | None = Header(default=None),
) -> AuthResult:
    try:
        email = normalize_email(payload.email)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from None

    result = await db.execute(select(User).where(User.email == email))
    if result.scalar_one_or_none() is not None:
        raise HTTPException(status_code=409, detail="An account with this email already exists")

    user = User(
        email=email,
        password_hash=hash_password(payload.password),
        display_name=payload.display_name.strip(),
        email_verified=False,
        phone_verified=False,
    )
    db.add(user)
    await db.flush()
    return await _authenticated_result(
        user=user,
        db=db,
        device_id=payload.device_id,
        user_agent=user_agent,
    )


@router.post("/email/login", response_model=AuthResult)
async def login_email(
    payload: EmailLogin,
    db: Db,
    user_agent: str | None = Header(default=None),
) -> AuthResult:
    try:
        email = normalize_email(payload.email)
    except ValueError:
        raise HTTPException(status_code=401, detail="Incorrect email or password") from None

    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()
    if user is None or user.password_hash is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Incorrect email or password")
    _ensure_account_available(user)
    return await _authenticated_result(
        user=user,
        db=db,
        device_id=payload.device_id,
        user_agent=user_agent,
    )


@router.post("/google", response_model=AuthResult)
async def login_google(
    payload: GoogleLogin,
    db: Db,
    user_agent: str | None = Header(default=None),
) -> AuthResult:
    try:
        claims = await verify_google_token(payload.id_token)
        email = normalize_email(str(claims["email"]))
        google_sub = str(claims["sub"])
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=401, detail="Google sign-in could not be verified") from exc

    result = await db.execute(select(User).where(User.google_sub == google_sub))
    user = result.scalar_one_or_none()
    if user is None:
        by_email = await db.execute(select(User).where(User.email == email))
        user = by_email.scalar_one_or_none()

    if user is None:
        user = User(
            email=email,
            google_sub=google_sub,
            display_name=(str(claims.get("name") or "").strip() or None),
            avatar_url=(str(claims.get("picture") or "").strip() or None),
            email_verified=True,
            phone_verified=False,
        )
        db.add(user)
        await db.flush()
    else:
        _ensure_account_available(user)
        if user.google_sub is not None and user.google_sub != google_sub:
            raise HTTPException(status_code=409, detail="This email is linked to a different Google account")
        user.google_sub = google_sub
        user.email = email
        user.email_verified = True
        if not user.display_name and claims.get("name"):
            user.display_name = str(claims["name"]).strip()[:120]
        if not user.avatar_url and claims.get("picture"):
            user.avatar_url = str(claims["picture"]).strip()[:1000]

    return await _authenticated_result(
        user=user,
        db=db,
        device_id=payload.device_id,
        user_agent=user_agent,
    )


@router.post("/refresh", response_model=TokenPair)
async def refresh(payload: RefreshRequest, db: Db) -> TokenPair:
    now = utcnow()
    token_hash = refresh_token_hash(payload.refresh_token)
    result = await db.execute(select(Session).where(Session.refresh_hash == token_hash).with_for_update())
    session = result.scalar_one_or_none()
    if session is None or session.revoked_at is not None or session.expires_at <= now:
        raise HTTPException(status_code=401, detail="Invalid refresh token")
    user = await db.get(User, session.user_id)
    if user is None or not user.is_active or user.deleted_at is not None or user.suspended_at is not None:
        session.revoked_at = now
        await db.commit()
        raise HTTPException(status_code=401, detail="Account unavailable")

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
