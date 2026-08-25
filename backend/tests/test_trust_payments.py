from __future__ import annotations

from fastapi.testclient import TestClient

from app.main import app


def login(client: TestClient, phone: str) -> dict[str, str]:
    requested = client.post("/v1/auth/otp/request", json={"phone": phone})
    assert requested.status_code == 201, requested.text
    body = requested.json()
    verified = client.post(
        "/v1/auth/otp/verify",
        json={
            "challenge_id": body["challenge_id"],
            "otp": body["development_otp"],
            "device_id": f"trust-{phone}",
        },
    )
    assert verified.status_code == 200, verified.text
    return verified.json()


def auth(session: dict[str, str]) -> dict[str, str]:
    return {"Authorization": f"Bearer {session['access_token']}"}


def make_booking(client: TestClient, customer: dict[str, str], provider_user: dict[str, str], suffix: str) -> tuple[dict, dict]:
    provider = client.put(
        "/v1/providers/me",
        headers=auth(provider_user),
        json={
            "kind": "individual",
            "display_name": f"Trust Provider {suffix}",
            "service_area": "Sonipat",
            "bio": "Verified test professional",
        },
    )
    assert provider.status_code == 200, provider.text
    listing = client.post(
        "/v1/services",
        headers=auth(provider_user),
        json={
            "title": f"AC Service {suffix}",
            "category": "AC Service",
            "description": "Complete AC cleaning",
            "area": "Sonipat",
            "price_paise": 75000,
            "pricing_unit": "fixed",
        },
    )
    assert listing.status_code == 201, listing.text
    booking = client.post(
        f"/v1/services/{listing.json()['id']}/book",
        headers=auth(customer),
        json={
            "scheduled_for": "2026-09-20T09:00:00+05:30",
            "area": "Sector 15, Sonipat",
        },
    )
    assert booking.status_code == 201, booking.text
    return provider.json(), booking.json()


def test_payment_completion_payout_reviews_and_identity() -> None:
    with TestClient(app) as client:
        customer = login(client, "9876500101")
        provider_user = login(client, "9876500102")
        provider, booking = make_booking(client, customer, provider_user, "A")
        booking_id = booking["id"]

        early_review = client.post(
            f"/v1/trust/bookings/{booking_id}/reviews",
            headers=auth(customer),
            json={"rating": 5, "comment": "Too early"},
        )
        assert early_review.status_code == 409

        payment = client.post(f"/v1/trust/bookings/{booking_id}/payment", headers=auth(customer))
        assert payment.status_code == 201, payment.text
        payment_data = payment.json()
        assert payment_data["amount_paise"] == booking["agreed_amount_paise"] == 75000
        assert payment_data["status"] == "created"

        duplicate = client.post(f"/v1/trust/bookings/{booking_id}/payment", headers=auth(customer))
        assert duplicate.status_code == 201
        assert duplicate.json()["id"] == payment_data["id"]

        captured = client.post(
            f"/v1/trust/payments/{payment_data['id']}/simulate-capture",
            headers=auth(customer),
        )
        assert captured.status_code == 200, captured.text
        assert captured.json()["status"] == "captured"

        code = client.post(f"/v1/ops/bookings/{booking_id}/start-code", headers=auth(customer))
        assert code.status_code == 200, code.text
        started = client.post(
            f"/v1/ops/bookings/{booking_id}/start",
            headers=auth(provider_user),
            json={"code": code.json()["code"]},
        )
        assert started.status_code == 200, started.text
        assert started.json()["status"] == "in_progress"

        completed = client.post(f"/v1/trust/bookings/{booking_id}/complete", headers=auth(customer))
        assert completed.status_code == 200, completed.text
        assert completed.json()["status"] == "completed"

        payouts = client.get("/v1/trust/payouts", headers=auth(provider_user))
        assert payouts.status_code == 200, payouts.text
        assert payouts.json()[0]["amount_paise"] == 75000
        assert payouts.json()[0]["status"] == "eligible"

        customer_review = client.post(
            f"/v1/trust/bookings/{booking_id}/reviews",
            headers=auth(customer),
            json={"rating": 5, "comment": "Excellent service"},
        )
        assert customer_review.status_code == 201, customer_review.text
        assert customer_review.json()["subject_provider_id"] == provider["id"]

        provider_review = client.post(
            f"/v1/trust/bookings/{booking_id}/reviews",
            headers=auth(provider_user),
            json={"rating": 4, "comment": "Good customer"},
        )
        assert provider_review.status_code == 201, provider_review.text
        assert provider_review.json()["subject_provider_id"] is None

        duplicate_review = client.post(
            f"/v1/trust/bookings/{booking_id}/reviews",
            headers=auth(customer),
            json={"rating": 5, "comment": "Duplicate"},
        )
        assert duplicate_review.status_code == 409

        summary = client.get(f"/v1/trust/providers/{provider['id']}/review-summary")
        assert summary.status_code == 200
        assert summary.json()["count"] == 1
        assert summary.json()["average_rating"] == 5.0

        verification = client.post(
            "/v1/trust/identity/verifications",
            headers=auth(customer),
            json={"method": "aadhaar_offline"},
        )
        assert verification.status_code == 201, verification.text
        assert "aadhaar_number" not in verification.json()
        verified = client.post(
            f"/v1/trust/identity/verifications/{verification.json()['id']}/simulate-verify",
            headers=auth(customer),
        )
        assert verified.status_code == 200
        assert verified.json()["status"] == "verified"
        overview = client.get("/v1/trust/overview", headers=auth(customer))
        assert overview.status_code == 200
        assert overview.json()["identity_verified"] is True


def test_dispute_holds_payout_and_development_refund() -> None:
    with TestClient(app) as client:
        customer = login(client, "9876500111")
        provider_user = login(client, "9876500112")
        _, booking = make_booking(client, customer, provider_user, "B")
        booking_id = booking["id"]
        payment = client.post(f"/v1/trust/bookings/{booking_id}/payment", headers=auth(customer))
        assert payment.status_code == 201
        payment_id = payment.json()["id"]
        assert client.post(f"/v1/trust/payments/{payment_id}/simulate-capture", headers=auth(customer)).status_code == 200

        dispute = client.post(
            f"/v1/trust/bookings/{booking_id}/disputes",
            headers=auth(customer),
            json={
                "category": "quality",
                "summary": "The work has a serious quality problem that needs review.",
                "requested_refund_paise": 30000,
            },
        )
        assert dispute.status_code == 201, dispute.text
        dispute_id = dispute.json()["id"]

        payouts = client.get("/v1/trust/payouts", headers=auth(provider_user))
        assert payouts.status_code == 200
        assert payouts.json()[0]["status"] == "held"
        assert "Open dispute" in payouts.json()[0]["hold_reason"]

        refund = client.post(
            f"/v1/trust/disputes/{dispute_id}/simulate-resolve",
            headers=auth(customer),
            json={"outcome": "refund", "refund_paise": 30000, "note": "Partial refund agreed in development test"},
        )
        assert refund.status_code == 200, refund.text
        assert refund.json()["amount_paise"] == 30000
        assert refund.json()["status"] == "completed"

        trust = client.get(f"/v1/trust/bookings/{booking_id}", headers=auth(customer))
        assert trust.status_code == 200
        assert trust.json()["payment"]["status"] == "partially_refunded"
        assert trust.json()["payment"]["refunded_paise"] == 30000
        assert trust.json()["payout"]["status"] == "held"

        outsider = login(client, "9876500113")
        forbidden = client.get(f"/v1/trust/bookings/{booking_id}", headers=auth(outsider))
        assert forbidden.status_code == 403
