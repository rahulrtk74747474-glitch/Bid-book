# Bid&Book Production Launch Runbook

This document covers the code-side launch path. Real credentials must be created in the relevant provider dashboards and stored only in the production secret/environment system.

## 1. Production host prerequisites

- Docker Engine + Docker Compose v2
- DNS record for the API domain pointing to the production host
- TCP 80/443 open to the internet
- encrypted host/storage volumes and regular off-host backups
- `.env.production` created from `.env.production.example`
- Firebase service-account JSON stored outside Git at `./secrets/firebase-service-account.json` if push delivery is enabled

## 2. Required external accounts

Before enabling each feature, configure:

- SMS/OTP delivery: `SMS_PROVIDER=http`, URL/token/sender ID
- payments: Razorpay key ID, key secret and webhook secret
- provider payouts: approved settlement provider URL/token/webhook secret
- identity verification: approved identity/KYC provider URL/token/webhook secret
- object storage: S3/S3-compatible bucket and credentials
- push: Firebase project/service-account plus Android/iOS Firebase app configuration
- app stores: Google Play Console + Apple Developer/App Store Connect

Never paste these production secrets into source code, Flutter `--dart-define` values (except public keys such as Razorpay key ID), issues, logs or chat.

## 3. First backend deployment

```bash
cp .env.production.example .env.production
# Edit .env.production locally on the host and replace every placeholder.

docker compose --env-file .env.production -f docker-compose.production.yml build
docker compose --env-file .env.production -f docker-compose.production.yml up -d postgres redis api caddy
```

The API container runs `alembic upgrade head` before Uvicorn starts. It does not use development `create_all()` in production.

Check:

```bash
curl -fsS https://$BIDBOOK_DOMAIN/live
curl -fsS https://$BIDBOOK_DOMAIN/ready
```

`/ready` checks both PostgreSQL and the distributed rate-limit store.

To enable push delivery after Firebase credentials are installed:

```bash
docker compose --env-file .env.production -f docker-compose.production.yml --profile push up -d push-worker
```

## 4. Provider webhooks

Configure provider webhooks to these HTTPS URLs:

- Razorpay: `https://<domain>/webhooks/razorpay`
- identity provider: `https://<domain>/webhooks/identity`
- payout provider: `https://<domain>/webhooks/payout`

Each provider must use its configured webhook secret. Bid&Book records event receipts with a unique provider/event ID so retries are idempotent.

Payment capture is authoritative only after the server processes a valid signed provider webhook. The Flutter checkout callback is not trusted as capture proof.

## 5. Object storage

Create a private bucket. Prefer bucket policies that deny public writes and allow only the deployment identity required by the backend.

The mobile app requests a short-lived presigned PUT URL from Bid&Book and uploads directly to object storage. After upload, the server calls object-storage metadata/head APIs and verifies existence, size and content type before the attachment becomes `ready`.

Allowed app evidence types remain intentionally narrow: JPEG, PNG, WebP and PDF.

## 6. Admin security

Set:

```text
ADMIN_PHONES=+91...
ADMIN_MFA_SECRET=<base32 authenticator secret>
```

Admin role is bootstrapped only from server configuration. The administrator first completes normal phone OTP login and must then pass a separate six-digit TOTP step-up before `/v1/admin/*` operations are accepted. Step-up tokens expire quickly.

Use a dedicated administrator phone/account. Do not share the TOTP seed among a large support team; move to per-admin MFA/SSO before scaling operations staff.

## 7. Database backup and restore

Back up before releases/migrations:

```bash
export POSTGRES_HOST=127.0.0.1 POSTGRES_DB=bidbook POSTGRES_USER=bidbook PGPASSWORD='...'
./tools/backup_postgres.sh
```

Restore is intentionally guarded:

```bash
export CONFIRM_RESTORE=RESTORE_BIDBOOK
./tools/restore_postgres.sh ./backups/bidbook-YYYYMMDDTHHMMSSZ.dump
```

Always test restore procedures on a separate environment. Backups that have never been restored in a drill are not sufficient disaster recovery.

## 8. Android/iOS bootstrap

If native wrapper directories are not committed on a development machine:

macOS/Linux:

```bash
./tools/bootstrap_mobile.sh
```

Windows PowerShell:

```powershell
./tools/bootstrap_mobile.ps1
```

The scripts generate Android+iOS wrappers, configure `com.bidbook.app`, apply required foreground location/photo/camera notification descriptions and run analyze/tests.

No background location permission is added.

## 9. Firebase mobile configuration

Firebase native app configuration is account-specific and must not be fabricated. Use the official FlutterFire setup for the real Firebase project, then keep service-account credentials out of Git.

Bid&Book catches missing Firebase runtime configuration so in-app notifications continue to work even if push is unavailable. Production QA must verify FCM/APNs on physical Android and iPhone devices before store submission.

## 10. Release builds

Use GitHub Actions → **Mobile release artifacts** and supply:

- production HTTPS API URL
- Razorpay public key ID (if enabled)

The workflow builds:

- Android release APK
- Android release AAB
- unsigned iOS release app archive for QA

The generated artifacts prove the code compiles against production configuration. Store submission still requires your actual Android upload key / Play App Signing and Apple signing team/certificates/profiles.

## 11. Pre-launch real-device scenario

Use at least two phones and complete this exact flow:

1. Customer OTP login
2. Provider OTP login
3. Provider verification/profile/location/service radius
4. Publish service
5. Customer posts request
6. Provider bids, then rebids
7. Confirm all old bids still exist
8. Customer accepts current exact bid
9. Chat/message notifications
10. Customer payment via real gateway
11. Confirm payment stays pending until signed webhook arrives
12. Assign technician (company flow)
13. Customer generates six-digit start code
14. Assigned provider/technician starts job with code
15. Customer confirms completion
16. Payout becomes eligible
17. Admin processes payout
18. Customer review
19. Warranty/dispute + evidence upload
20. Refund path in a controlled sandbox booking
21. Account data export
22. Suspension and session revocation test

Repeat the group-buying flow separately with multiple members and multiple provider bids.

## 12. Launch gates

Do not enable real money publicly until all are true:

- backend CI and Flutter CI green on release commit
- migrations tested from a production-like backup
- HTTPS and DNS stable
- real SMS delivery verified
- real payment webhook signature verified
- real refund verified in provider sandbox/live-small-value environment
- real payout settlement/reconciliation verified
- identity provider legal/compliance review complete
- push delivery verified on Android and iOS
- privacy/terms/refund/provider agreements reviewed by qualified local counsel/accounting advisers
- Google Play Data safety and App Store privacy declarations match actual runtime behavior
- independent security assessment / penetration test completed
- incident response and backup restore owner assigned
