# Bid&Book Trust & Payments

## Money flow

1. A booking stores the exact agreed amount from a service listing or accepted bid event.
2. The customer creates a payment intent. The mobile client never supplies the amount.
3. A payment gateway adapter creates the external payment reference.
4. After capture, a provider payout record is created in `pending` state.
5. The assigned provider can mark the job `in_progress` only after captured payment.
6. The customer confirms completion.
7. The payout becomes `eligible` unless an unresolved dispute holds it.
8. A production settlement worker/payment-provider integration will move eligible payouts to `processing` and `paid`.

The repository includes a development payment adapter only. Production intentionally fails closed until a real compliant gateway adapter is configured. No card number, UPI PIN, CVV, bank password, or gateway secret belongs in the app database or mobile source.

## Disputes and refunds

Either booking participant can open a dispute. When a dispute opens, any unpaid payout is moved to `held`. Refund requests cannot exceed the remaining captured payment balance.

The development-only resolution endpoint exists for automated tests and local demos. Production dispute resolution should be an authenticated internal operations workflow with audit logs and gateway webhooks.

## Reviews

Reviews are permitted only after a booking is completed. Customer and provider can each review the other participant once per booking. Provider review summaries are calculated from completed-booking reviews.

## Identity verification

`identity_verifications` stores only:

- verification method
- status
- external provider name/reference
- timestamps
- failure reason when applicable

The current flow does **not** store Aadhaar number, Aadhaar OTP, fingerprint, iris, PID data, or a raw Aadhaar document. Aadhaar Offline e-KYC is represented as one verification method, not as a platform-wide identity key.

## Risk signals

Risk signals are entity-level operational signals. Opening a dispute creates a booking-level signal for review; it does not automatically label either participant as fraudulent. Automatic suspension or high-impact decisions should not be based on a single signal.

## Before production payments

- implement a licensed/compliant payment gateway adapter
- verify payment/refund webhooks cryptographically
- add idempotency keys and webhook replay protection
- configure payout/settlement rules with finance/legal review
- add internal dispute/admin authorization and immutable audit events
- add database migrations instead of development `create_all`
- complete independent security testing
