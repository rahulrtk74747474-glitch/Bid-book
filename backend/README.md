# Bid&Book backend

FastAPI + PostgreSQL backend for the Bid&Book Android/iOS marketplace.

## Implemented

- Server-generated OTP challenges (HMAC-digested, expiring, attempt-limited, cooldown/hourly throttled)
- Short-lived JWT access tokens
- Opaque refresh tokens stored only as SHA-256 hashes and rotated on every refresh
- Revocable device sessions
- Unified customer/provider accounts
- Provider profiles and service listings
- Direct service bookings
- Persistent service requests
- Append-only bid events; no update/delete bid endpoint exists
- Historical bid rejection during award
- Request row locking during award to prevent double booking
- Booking snapshot of accepted bid-event ID and agreed amount
- Neighborhood groups, invite membership, admin proposals, voting/quantity aggregation and publishing to the bidding marketplace
- Audit records for high-value marketplace actions

## Local run

From repository root:

```bash
docker compose -f docker-compose.backend.yml up --build
```

Then open `http://127.0.0.1:8000/docs` for the development API explorer.

In development only, `/v1/auth/otp/request` can return `development_otp` when `EXPOSE_DEVELOPMENT_OTP=true`. Production configuration refuses to start if development secrets or OTP exposure are enabled.

## Production rules

- Set `ENVIRONMENT=production`.
- Use strong secrets from a cloud secrets manager/KMS, never `.env` committed to Git.
- Set `EXPOSE_DEVELOPMENT_OTP=false` and replace `DevelopmentSmsSender` with an approved SMS provider integration.
- Run behind TLS, WAF/API gateway, structured logging, monitoring and backups.
- Replace development table auto-creation with versioned database migrations before deployment.
- Add Redis-backed distributed rate limiting before horizontal scale.
- Identity verification should store a verification result/reference, not raw Aadhaar/OTP/biometric data.
