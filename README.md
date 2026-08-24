# Bid&Book

Bid&Book is a Flutter mobile marketplace for Android and iOS where customers can book local independent workers or companies, post work requests for competitive bidding, and organize neighborhood group-buying requests.

## Implemented mobile flow

The current app foundation now supports an end-to-end local demo flow:

1. Mobile OTP sign-in screen.
2. One account can act as both customer and service provider.
3. Provider onboarding for an independent worker or company.
4. Provider can publish a service with price, pricing unit and service area.
5. Customers can directly book published services.
6. Customers can post service requests with category, description, area and preferred date/time.
7. Eligible providers can place a bid or revise an existing bid.
8. Every bid/rebid remains visible in immutable history.
9. Only the provider's latest bid is considered a current offer; older offers remain historical and cannot be awarded.
10. The request owner can accept an exact current bid.
11. A confirmed booking snapshots the accepted `bidEventId` and amount so later changes cannot alter the agreement.
12. Users can view their bookings from Account.

## Non-negotiable bidding rule

Every bid and every rebid is append-only. A newer price never overwrites an earlier submission. Authorized users can inspect the complete bid history for a request.

Example:

```text
CoolCare      ₹349   Initial
FreshAir      ₹335   Initial
CoolCare      ₹325   Revised
CoolCare      ₹315   Revised
```

The ₹349 and ₹325 entries remain in history after the ₹315 revision. Only ₹315 is the current CoolCare offer.

## Authentication note

The repository currently uses a clearly labelled **development OTP (`123456`)** so the complete mobile flow can be exercised without storing SMS credentials in source control. This is not production authentication. The production backend will issue short-lived OTP challenges with rate limits, attempt limits, device/risk signals and server-side session tokens.

## Security invariants already represented in code

- Bid events are append-only.
- Historical provider bids are not awardable after a revision.
- Only the request owner can accept a bid.
- Booking records snapshot the accepted bid-event ID and agreed amount.
- Users cannot directly book their own public service listing.
- Identity verification is modeled as status; raw Aadhaar data is not part of the app domain model.

## Architecture

Feature-first Flutter structure:

```text
lib/
  core/
  features/
    auth/
    bidding/
    bookings/
    groups/
    marketplace/
    profile/
    provider/
    requests/
    services/
  shared/
```

State is currently held in Riverpod in-memory repositories/controllers. This intentionally keeps the UI independent from the future server implementation. The next backend phase will replace these data sources with authenticated API repositories while preserving the domain/UI contracts.

## Run locally

Install Flutter stable, then:

```bash
flutter pub get
flutter run
```

Run checks:

```bash
flutter analyze
flutter test
```

## Production roadmap after this slice

Next major engineering work is the secure backend/API layer: PostgreSQL, server OTP, access/refresh sessions, provider/service persistence, request/bid/booking transactions, WebSocket or push updates, payment integration, identity-verification provider integration, rate limiting, audit logs and fraud controls. Neighborhood membership/voting will then use the same persistent request/bid infrastructure.
