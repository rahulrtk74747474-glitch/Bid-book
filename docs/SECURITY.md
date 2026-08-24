# Bid&Book security baseline

Bid&Book is intended to handle identity, location, bookings, payments, messaging and reputation data. Security is therefore a product requirement, not a later add-on.

## Identity

- Do not store raw Aadhaar numbers unless a specific lawful, reviewed flow requires it.
- Prefer a verification provider / UIDAI-compliant mechanism and retain only the minimum verification result and audit reference required.
- Never store Aadhaar OTPs or biometric authentication data.
- Separate identity verification from trust: a verified identity can still behave fraudulently.

## Authentication and sessions

- Mobile OTP/passkey-ready authentication.
- Short-lived access tokens and rotating refresh tokens.
- Per-device sessions and remote logout.
- Rate-limit OTP sending and verification by phone, device, account and network signals.
- Require stronger authentication for company admins and internal staff.

## Authorization

Every API checks object-level authorization server-side. Group membership, group admin rights, request ownership, provider ownership, accepted bids, messages, payments and disputes must never rely on client-side checks alone.

## Bidding integrity

- Submitted bid events are append-only.
- A revision creates a new event linked to the previous event.
- Awarding references an exact immutable bid-event ID.
- Server timestamps are authoritative.
- Request closure prevents ordinary later bidding.
- Privileged corrections require audited administrative actions rather than silent mutation.

## Payments

- Use a regulated payment provider/payment aggregator.
- Do not store card PAN/CVV.
- Verify payment-provider webhooks cryptographically.
- Make payment and payout operations idempotent.
- Separate booking status from payment status.

## Data protection

- TLS for all traffic.
- Encryption at rest for databases and object storage.
- KMS/secrets manager for production secrets.
- Minimize precise location retention and do not publicly expose worker/customer home coordinates.
- Use signed, expiring URLs for private uploads.
- Malware/content checks for uploaded files.

## Mobile

- Store tokens only in OS secure storage (Android Keystore / iOS Keychain).
- No production secrets embedded in the application bundle.
- Use Play Integrity / Apple App Attest style signals where valuable, without treating device attestation as the sole security boundary.
- Keep permissions minimal; avoid background location unless a future feature genuinely requires it.

## Operations

- Separate production and non-production environments.
- Least-privilege internal roles.
- Audit privileged support/admin actions.
- Automated backups plus tested restore procedures.
- Dependency/security scanning in CI.
- Independent security review and penetration testing before large-scale production launch.
