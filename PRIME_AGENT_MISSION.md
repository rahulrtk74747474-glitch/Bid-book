# Bid&Book Prime Agent Mission

You are working on the Bid&Book Flutter + FastAPI project.

## Primary goal
Improve, test, and package Bid&Book without changing its core marketplace guarantees.

## Non-negotiable invariant
Every bid and every rebid must remain permanently visible. New bids must never overwrite old bids.

Required semantics:
- rebids create new append-only bid events;
- old bid events remain queryable and visible in history;
- only the latest current offer from a provider is awardable;
- accepted bookings snapshot the exact accepted bid-event ID and accepted amount;
- a future rebid must never alter an existing booking price.

Never replace this with a single mutable `current_bid` record.

## Product direction
Use the Professional Trust design:
- deep navy + white + royal blue;
- green only for verification/trust states;
- orange for bidding;
- blue for booking;
- purple for group buying;
- clean cards, large service/provider imagery, strong trust signals;
- obvious `Bid ₹ — Enter your price` actions where eligible;
- multiple photo uploads for customer requests and provider/service media;
- login paths for Phone OTP, Email/Password, Google, and Create Account.

Do not invent ratings, job counts, verification, response times, or other trust metrics unless backed by real persisted data.

## Engineering rules
1. Read the existing code and tests before changing architecture.
2. Keep backend API under `/v1` consistent with Flutter configuration.
3. Do not commit production credentials, signing keys, OAuth secrets, SMS keys, payment keys, or storage keys.
4. Google sign-in is not production-ready until real OAuth client configuration is supplied.
5. Photo upload must transfer actual bytes; do not fake a successful upload with metadata only.
6. Preserve group buying and chat functionality while redesigning navigation.
7. Prefer small reviewable commits.
8. Before declaring success run:
   - `flutter pub get`
   - `flutter analyze`
   - `flutter test`
   - backend tests
9. For APK packaging, use `tools/build_android_apk.sh <API_URL>` after checks pass.
10. Never merge or push destructive changes directly to `main` without review.

## First task
Inspect the current repository, summarize what is working and what is incomplete, then create a prioritized implementation plan. Pay special attention to authentication, real media upload, bidding UX, Android packaging, and test coverage. Do not change the append-only bid-history invariant.
