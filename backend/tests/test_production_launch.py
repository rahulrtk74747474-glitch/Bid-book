from __future__ import annotations

import hashlib
import hmac
import json

from fastapi.testclient import TestClient

from app.main import app


def login(client: TestClient, phone: str) -> dict:
    requested = client.post("/v1/auth/otp/request", json={"phone": phone})
    assert requested.status_code == 201, requested.text
    challenge = requested.json()
    verified = client.post(
        "/v1/auth/otp/verify",
        json={
            "challenge_id": challenge["challenge_id"],
            "otp": challenge["development_otp"],
            "device_id": f"production-{phone}",
        },
    )
    assert verified.status_code == 200, verified.text
    return verified.json()


def auth(session: dict) -> dict[str, str]:
    return {"Authorization": f"Bearer {session['access_token']}"}


def create_provider(client: TestClient, session: dict, suffix: str = "") -> dict:
    response = client.put(
        "/v1/providers/me",
        headers=auth(session),
        json={
            "kind": "company" if suffix == "team" else "individual",
            "display_name": f"Launch Provider {suffix}".strip(),
            "service_area": "Sonipat",
            "bio": "Production launch integration provider",
        },
    )
    assert response.status_code == 200, response.text
    return response.json()


def create_service(client: TestClient, session: dict, suffix: str = "") -> dict:
    response = client.post(
        "/v1/services",
        headers=auth(session),
        json={
            "title": f"Production AC Service {suffix}".strip(),
            "category": "AC Service",
            "description": "Production launch service listing",
            "area": "Sonipat",
            "price_paise": 100000,
            "pricing_unit": "fixed",
        },
    )
    assert response.status_code == 201, response.text
    return response.json()


def test_extended_provider_nearby_export_and_fee_aware_payment() -> None:
    with TestClient(app) as client:
        provider_user = login(client, "9876500201")
        customer = login(client, "9876500202")
        provider = create_provider(client, provider_user, "nearby")
        listing = create_service(client, provider_user, "nearby")

        extended = client.put(
            "/v1/production/provider/profile",
            headers=auth(provider_user),
            json={
                "years_experience": 8,
                "languages": ["Hindi", "English"],
                "skills": ["AC Service", "Split AC"],
                "gstin": None,
                "service_radius_km": 20,
                "latitude": 28.9931,
                "longitude": 77.0151,
                "payout_method_label": "Marketplace settlement account",
                "portfolio_headline": "Eight years of AC service experience",
            },
        )
        assert extended.status_code == 200, extended.text
        assert extended.json()["service_radius_km"] == 20
        assert extended.json()["languages"] == ["English", "Hindi"]

        nearby = client.get(
            "/v1/production/discovery/nearby",
            headers=auth(customer),
            params={
                "latitude": 28.9940,
                "longitude": 77.0160,
                "radius_km": 25,
                "category": "AC",
            },
        )
        assert nearby.status_code == 200, nearby.text
        rows = nearby.json()
        assert any(row["provider_id"] == provider["id"] and row["id"] == listing["id"] for row in rows)
        assert rows[0]["distance_km"] is not None

        booking = client.post(
            f"/v1/services/{listing['id']}/book",
            headers=auth(customer),
            json={"scheduled_for": "2026-10-02T10:00:00+05:30", "area": "Sonipat"},
        )
        assert booking.status_code == 201, booking.text
        payment = client.post(
            f"/v1/production/bookings/{booking.json()['id']}/payment",
            headers=auth(customer),
        )
        assert payment.status_code == 201, payment.text
        assert payment.json()["amount_paise"] == 100000
        assert payment.json()["platform_fee_paise"] == 5000

        export = client.get("/v1/production/account/export", headers=auth(customer))
        assert export.status_code == 200, export.text
        assert export.json()["user"]["id"] == customer["user"]["id"]
        assert len(export.json()["bookings"]) >= 1
        assert len(export.json()["payments"]) >= 1


def test_company_staff_assignment_and_assigned_technician_start() -> None:
    with TestClient(app) as client:
        owner = login(client, "9876500203")
        technician = login(client, "9876500204")
        customer = login(client, "9876500205")
        create_provider(client, owner, "team")
        listing = create_service(client, owner, "team")

        staff = client.post(
            "/v1/production/provider/staff",
            headers=auth(owner),
            json={"phone": "9876500204", "role": "technician"},
        )
        assert staff.status_code == 201, staff.text
        assert staff.json()["user_id"] == technician["user"]["id"]

        booking = client.post(
            f"/v1/services/{listing['id']}/book",
            headers=auth(customer),
            json={"scheduled_for": "2026-10-03T11:00:00+05:30", "area": "Sonipat"},
        )
        assert booking.status_code == 201, booking.text
        booking_id = booking.json()["id"]

        assignment = client.post(
            f"/v1/production/bookings/{booking_id}/assignment",
            headers=auth(owner),
            json={"staff_user_id": technician["user"]["id"]},
        )
        assert assignment.status_code == 200, assignment.text

        payment = client.post(
            f"/v1/production/bookings/{booking_id}/payment",
            headers=auth(customer),
        )
        assert payment.status_code == 201, payment.text
        capture = client.post(
            f"/v1/trust/payments/{payment.json()['id']}/simulate-capture",
            headers=auth(customer),
        )
        assert capture.status_code == 200, capture.text

        start_code = client.post(
            f"/v1/ops/bookings/{booking_id}/start-code",
            headers=auth(customer),
        )
        assert start_code.status_code == 200, start_code.text
        started = client.post(
            f"/v1/ops/bookings/{booking_id}/start",
            headers=auth(technician),
            json={"code": start_code.json()["code"]},
        )
        assert started.status_code == 200, started.text
        assert started.json()["status"] == "in_progress"


def test_admin_stepup_and_identity_webhook_idempotency() -> None:
    with TestClient(app) as client:
        admin = login(client, "9876500091")
        assert admin["user"]["is_admin"] is True
        stepup = client.post(
            "/v1/production/admin/step-up",
            headers=auth(admin),
            json={"code": "000000"},
        )
        assert stepup.status_code == 200, stepup.text
        assert stepup.json()["token"]

        user = login(client, "9876500206")
        verification = client.post(
            "/v1/trust/identity/verifications",
            headers=auth(user),
            json={"method": "government_id"},
        )
        assert verification.status_code == 201, verification.text
        reference = verification.json()["provider_reference"]
        payload = {
            "event_id": "identity-launch-test-1",
            "reference": reference,
            "status": "verified",
        }
        raw = json.dumps(payload, separators=(",", ":")).encode()
        signature = hmac.new(
            b"test-identity-webhook-secret",
            raw,
            hashlib.sha256,
        ).hexdigest()
        webhook = client.post(
            "/webhooks/identity",
            content=raw,
            headers={
                "Content-Type": "application/json",
                "X-BidBook-Signature": signature,
            },
        )
        assert webhook.status_code == 200, webhook.text
        assert webhook.json()["duplicate"] is False

        duplicate = client.post(
            "/webhooks/identity",
            content=raw,
            headers={
                "Content-Type": "application/json",
                "X-BidBook-Signature": signature,
            },
        )
        assert duplicate.status_code == 200
        assert duplicate.json()["duplicate"] is True

        me = client.get("/v1/auth/me", headers=auth(user))
        assert me.status_code == 200
        assert me.json()["identity_verified"] is True
