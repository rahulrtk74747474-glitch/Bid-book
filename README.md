# Bid&Book

**Bid&Book** is an Android/iOS local-services marketplace built with Flutter. People can book nearby independent workers and companies, post service requests, and create neighborhood groups that aggregate demand and invite providers to compete for the work.

## Core product rule: transparent bid history

Every bid and every rebid is append-only. A newer price never overwrites an earlier submission. Authorized participants can inspect the complete bid history for a request.

Example:

- CoolCare — ₹349 — initial bid
- FreshAir — ₹335 — initial bid
- CoolCare — ₹325 — revised bid
- CoolCare — ₹315 — revised bid

The ₹349 and ₹325 submissions remain visible after ₹315 is submitted.

## Product pillars

### Book
Search local professionals/services and book a listed service.

### Bid
Post a service requirement and receive transparent competitive bids from independent workers or registered companies.

### Groups
Neighbors can create a group. An admin raises a proposed requirement, members accept/reject/express interest, aggregated demand is published, providers bid, and the group admin selects an exact bid offer.

## Mobile stack

- Flutter / Dart
- Riverpod for application state
- go_router for navigation
- Material 3 UI
- Android and iOS only

Display name: `Bid&Book`

Dart package name: `bid_book`

Recommended Android application ID / iOS bundle namespace: `com.bidbook.app` (confirm ownership strategy before store release).

## Current foundation

Implemented on the `app-foundation` branch:

- Home/service discovery
- Requests marketplace
- Complete bid-history view
- Initial bid + rebid interaction
- Append-only immutable bid-event model
- Automated test preventing rebids from overwriting older prices
- Neighborhood groups/proposal starter
- Unified customer/provider profile concept
- Mobile navigation
- Security baseline
- Backend/domain architecture

## First local setup

Install a current stable Flutter SDK, then clone the repository and run:

```bash
git clone https://github.com/rahulrtk74747474-glitch/Bid-book.git
cd Bid-book
git checkout app-foundation
flutter create . --platforms=android,ios --org com.bidbook --project-name bid_book
flutter pub get
flutter test
flutter run
```

`flutter create .` is needed once to generate the native Android/iOS project shells. Do not routinely regenerate those folders after app-specific native settings are added.

## First end-to-end milestone

The next production slice should implement:

1. Mobile OTP authentication and secure device sessions
2. Unified customer/provider onboarding
3. Provider service listings with pricing and service radius
4. Customer service-request creation
5. Backend append-only bidding API
6. Full visible bid history
7. Awarding one exact immutable bid event
8. Neighborhood group creation/invites/admin roles
9. Group proposals, member responses, quantities and thresholds
10. Aggregated group request publishing and provider bidding

After that: chat, bookings, payments/payouts, identity verification, reviews, warranty/disputes, trust/safety and fraud controls.

## Important documentation

- `docs/BIDDING_RULES.md`
- `docs/ARCHITECTURE.md`
- `docs/SECURITY.md`
