from __future__ import annotations

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
            "device_id": f"ops-{phone}",
        },
    )
    assert verified.status_code == 200, verified.text
    return verified.json()


def auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def test_admin_bootstrap_support_report_and_suspension() -> None:
    with TestClient(app) as client:
        admin = login(client, "9876500091")
        assert admin["user"]["is_admin"] is True
        user = login(client, "9876500092")
        user_headers = auth(user["access_token"])
        admin_headers = auth(admin["access_token"])

        support = client.post(
            "/v1/ops/support/cases",
            headers=user_headers,
            json={
                "subject": "Need help with booking",
                "category": "booking",
                "description": "The provider and I need help resolving a booking question.",
                "priority": "normal",
            },
        )
        assert support.status_code == 201, support.text
        case_id = support.json()["id"]
        message = client.post(
            f"/v1/ops/support/cases/{case_id}/messages",
            headers=user_headers,
            json={"body": "Please review the booking history."},
        )
        assert message.status_code == 201, message.text

        report = client.post(
            "/v1/ops/reports",
            headers=user_headers,
            json={
                "entity_type": "user",
                "entity_id": admin["user"]["id"],
                "category": "test_report",
                "summary": "Test moderation report for integration coverage.",
            },
        )
        assert report.status_code == 201, report.text

        overview = client.get("/v1/admin/overview", headers=admin_headers)
        assert overview.status_code == 200, overview.text
        assert overview.json()["open_support_cases"] >= 1
        assert overview.json()["open_reports"] >= 1

        suspended = client.post(
            f"/v1/admin/users/{user['user']['id']}/suspend",
            headers=admin_headers,
            json={"reason": "Integration-test suspension"},
        )
        assert suspended.status_code == 200, suspended.text
        denied = client.get("/v1/auth/me", headers=user_headers)
        assert denied.status_code == 401
        otp_denied = client.post("/v1/auth/otp/request", json={"phone": "9876500092"})
        assert otp_denied.status_code == 403

        restored = client.post(
            f"/v1/admin/users/{user['user']['id']}/restore",
            headers=admin_headers,
        )
        assert restored.status_code == 200, restored.text
        again = login(client, "9876500092")
        assert again["user"]["id"] == user["user"]["id"]


def test_discovery_availability_blocking_and_verification_review() -> None:
    with TestClient(app) as client:
        admin = login(client, "9876500091")
        provider_user = login(client, "9876500093")
        customer = login(client, "9876500094")
        provider_headers = auth(provider_user["access_token"])
        customer_headers = auth(customer["access_token"])
        admin_headers = auth(admin["access_token"])

        provider = client.put(
            "/v1/providers/me",
            headers=provider_headers,
            json={
                "kind": "individual",
                "display_name": "Verified Discovery Tech",
                "service_area": "Sonipat",
                "bio": "Appliance repair specialist",
            },
        )
        assert provider.status_code == 200, provider.text
        provider_id = provider.json()["id"]
        availability = client.put(
            "/v1/ops/provider/availability",
            headers=provider_headers,
            json={"slots": [{"weekday": 1, "start_minute": 540, "end_minute": 1020, "active": True}]},
        )
        assert availability.status_code == 200, availability.text

        service = client.post(
            "/v1/services",
            headers=provider_headers,
            json={
                "title": "Washing machine repair",
                "category": "Appliance Repair",
                "description": "Diagnosis and repair visit",
                "area": "Sonipat",
                "price_paise": 59900,
                "pricing_unit": "fixed",
            },
        )
        assert service.status_code == 201, service.text

        found = client.get(
            "/v1/ops/discovery/services",
            headers=customer_headers,
            params={"q": "washing", "weekday": 1},
        )
        assert found.status_code == 200, found.text
        rows = found.json()
        assert any(row["provider_id"] == provider_id and row["provider_name"] == "Verified Discovery Tech" for row in rows)

        verification = client.post(
            "/v1/trust/identity/verifications",
            headers=provider_headers,
            json={"method": "government_id"},
        )
        assert verification.status_code == 201, verification.text
        decided = client.post(
            f"/v1/admin/verifications/{verification.json()['id']}/decision",
            headers=admin_headers,
            json={"status": "verified"},
        )
        assert decided.status_code == 200, decided.text

        verified_found = client.get(
            "/v1/ops/discovery/services",
            headers=customer_headers,
            params={"q": "washing", "verified_only": True},
        )
        assert verified_found.status_code == 200
        assert any(row["provider_verified"] is True for row in verified_found.json())

        blocked = client.put(
            f"/v1/ops/blocks/{provider_user['user']['id']}",
            headers=customer_headers,
        )
        assert blocked.status_code == 204, blocked.text
        hidden = client.get(
            "/v1/ops/discovery/services",
            headers=customer_headers,
            params={"q": "washing"},
        )
        assert hidden.status_code == 200
        assert all(row["provider_id"] != provider_id for row in hidden.json())


def test_secure_start_code_completion_and_warranty() -> None:
    with TestClient(app) as client:
        customer = login(client, "9876500095")
        provider_user = login(client, "9876500096")
        customer_headers = auth(customer["access_token"])
        provider_headers = auth(provider_user["access_token"])

        provider = client.put(
            "/v1/providers/me",
            headers=provider_headers,
            json={
                "kind": "individual",
                "display_name": "Secure Start Tech",
                "service_area": "Sonipat",
                "bio": "Electrician",
            },
        )
        assert provider.status_code == 200, provider.text
        service = client.post(
            "/v1/services",
            headers=provider_headers,
            json={
                "title": "Electrical repair",
                "category": "Electrician",
                "description": "Home electrical repair",
                "area": "Sonipat",
                "price_paise": 75000,
                "pricing_unit": "fixed",
            },
        )
        assert service.status_code == 201, service.text
        booking = client.post(
            f"/v1/services/{service.json()['id']}/book",
            headers=customer_headers,
            json={"scheduled_for": "2026-09-25T10:00:00+05:30", "area": "Sonipat"},
        )
        assert booking.status_code == 201, booking.text
        booking_id = booking.json()["id"]

        payment = client.post(f"/v1/trust/bookings/{booking_id}/payment", headers=customer_headers)
        assert payment.status_code == 201, payment.text
        capture = client.post(
            f"/v1/trust/payments/{payment.json()['id']}/simulate-capture",
            headers=customer_headers,
        )
        assert capture.status_code == 200, capture.text

        code = client.post(f"/v1/ops/bookings/{booking_id}/start-code", headers=customer_headers)
        assert code.status_code == 200, code.text
        start_code = code.json()["code"]
        assert len(start_code) == 6

        legacy = client.post(f"/v1/trust/bookings/{booking_id}/start", headers=provider_headers)
        assert legacy.status_code == 410
        wrong = client.post(
            f"/v1/ops/bookings/{booking_id}/start",
            headers=provider_headers,
            json={"code": "000000" if start_code != "000000" else "111111"},
        )
        assert wrong.status_code == 401
        started = client.post(
            f"/v1/ops/bookings/{booking_id}/start",
            headers=provider_headers,
            json={"code": start_code},
        )
        assert started.status_code == 200, started.text
        assert started.json()["status"] == "in_progress"

        completed = client.post(f"/v1/trust/bookings/{booking_id}/complete", headers=customer_headers)
        assert completed.status_code == 200, completed.text
        warranty = client.post(
            f"/v1/ops/bookings/{booking_id}/warranty-claims",
            headers=customer_headers,
            json={"issue": "The repaired switch stopped working again."},
        )
        assert warranty.status_code == 201, warranty.text
        assert warranty.json()["status"] == "open"
