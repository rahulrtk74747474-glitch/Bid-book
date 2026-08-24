# Bid&Book bidding rules

## 1. Bid history is append-only

A bid submission is an immutable ledger event. If a provider changes the price, the platform creates a new event. It does not update or delete the previous event.

Each event should eventually contain at least:

- unique bid event ID
- service request ID
- provider ID
- amount in minor currency units (paise for INR)
- server-generated timestamp
- event type: initial or revised
- previous bid event ID when this is a revision
- provider-visible note/terms
- audit metadata

## 2. Visibility

For transparent/open bidding, authorized participants can see the complete chronological price history for the request, including earlier prices from the same provider.

Example:

- CoolCare — ₹349 — initial
- FreshAir — ₹335 — initial
- CoolCare — ₹325 — revised
- CoolCare — ₹315 — revised

The ₹349 and ₹325 entries remain visible after ₹315 is submitted.

## 3. Awarding

The customer or authorized group admin accepts a specific bid event, not simply a provider ID. The award record therefore stores `accepted_bid_event_id` so the accepted price and terms cannot change after selection.

## 4. Closing

Once a request is closed/awarded, normal providers cannot submit new bids. Reopening bidding is a separate audited action.

## 5. Server enforcement

The mobile implementation demonstrates the rule, but production enforcement belongs on the backend and database. The API must not expose an endpoint that mutates an existing submitted bid price.

Recommended operations:

- `POST /requests/{id}/bids` — create initial or revised bid event
- `GET /requests/{id}/bids/history` — read complete visible history
- `POST /requests/{id}/award` — accept one immutable bid event

Avoid `PUT/PATCH /bids/{bidId}` for submitted price changes.
