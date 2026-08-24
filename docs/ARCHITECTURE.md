# Bid&Book architecture

## Mobile-only clients

The product ships as Android and iOS applications from one Flutter codebase. There is no public web client in the current product scope.

## Client structure

Feature-oriented Flutter modules:

- authentication
- identity
- home/service discovery
- provider profiles and service listings
- service requests
- bidding
- neighborhood groups
- bookings
- chat
- payments/payouts
- reviews
- disputes/warranty
- account/security

UI code must not become the source of truth for money, authorization, bid history, group roles or booking state.

## Backend direction

Start with a modular API rather than premature microservices. Suggested bounded modules:

- users/auth
- identity verification
- providers/services
- requests
- bidding ledger
- groups/voting
- bookings
- payments
- messaging
- reviews/trust
- disputes
- notifications
- fraud/risk
- admin/audit

Suggested production data layer:

- PostgreSQL for transactional data
- PostGIS for proximity/service-area queries
- Redis for caching, rate limits and ephemeral coordination
- object storage for photos/documents
- queue for notifications, uploads and other async jobs
- OpenSearch only when marketplace search scale requires it

## Core entities

- users
- user_devices
- sessions
- identity_verifications
- provider_profiles
- service_categories
- provider_services
- service_areas
- service_requests
- request_media
- bid_events
- bid_awards
- groups
- group_members
- group_roles
- group_proposals
- group_votes
- group_demand_items
- bookings
- booking_events
- payments
- payouts
- chats
- messages
- reviews
- disputes
- reports
- risk_signals
- audit_logs

## Group request lifecycle

1. A verified member creates a neighborhood group.
2. Group owner/admin invites or approves members.
3. Admin raises a service proposal with date/time and requirements.
4. Members respond interested / reject / maybe and provide quantities when relevant.
5. The configured group threshold is reached.
6. Admin publishes an aggregated service request.
7. Eligible independent workers and companies submit bids.
8. Every bid/rebid becomes an immutable visible bid event.
9. Admin selects one exact bid event according to group rules.
10. Participating members confirm/book/pay their share.
11. Provider fulfills jobs and members confirm completion.
12. Reviews, warranty and dispute flows remain tied to the booking records.

## Scaling principle

Keep boundaries clean enough to extract high-load areas later. Chat, search, notifications and payments can become separate services when actual scale requires independent deployment. Do not begin with dozens of microservices solely because the long-term target is millions of users.
