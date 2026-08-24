from __future__ import annotations

from fastapi.testclient import TestClient

from app.main import app


def login(client: TestClient, phone: str) -> dict[str, str]:
    requested = client.post("/v1/auth/otp/request", json={"phone": phone})
    assert requested.status_code == 201, requested.text
    body = requested.json()
    assert body["development_otp"]
    verified = client.post(
        "/v1/auth/otp/verify",
        json={
            "challenge_id": body["challenge_id"],
            "otp": body["development_otp"],
            "device_id": f"test-{phone}",
        },
    )
    assert verified.status_code == 200, verified.text
    return verified.json()


def auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def test_health_and_refresh_rotation() -> None:
    with TestClient(app) as client:
        assert client.get("/health").json() == {"status": "ok"}
        session = login(client, "9876500001")
        refreshed = client.post("/v1/auth/refresh", json={"refresh_token": session["refresh_token"]})
        assert refreshed.status_code == 200
        rotated = refreshed.json()
        assert rotated["refresh_token"] != session["refresh_token"]
        reused = client.post("/v1/auth/refresh", json={"refresh_token": session["refresh_token"]})
        assert reused.status_code == 401


def test_append_only_bid_history_and_exact_award() -> None:
    with TestClient(app) as client:
        customer = login(client, "9876500011")
        provider_user = login(client, "9876500012")
        provider = client.put(
            "/v1/providers/me",
            headers=auth(provider_user["access_token"]),
            json={
                "kind": "individual",
                "display_name": "CoolCare Test",
                "service_area": "Sonipat",
                "bio": "AC technician",
            },
        )
        assert provider.status_code == 200, provider.text
        request = client.post(
            "/v1/requests",
            headers=auth(customer["access_token"]),
            json={
                "title": "AC service",
                "category": "AC Service",
                "description": "Need one AC serviced",
                "area": "Sector 15, Sonipat",
                "requested_for": "2026-09-10T09:00:00+05:30",
            },
        )
        assert request.status_code == 201, request.text
        request_id = request.json()["id"]
        first = client.post(
            f"/v1/requests/{request_id}/bids",
            headers=auth(provider_user["access_token"]),
            json={"amount_paise": 34900, "note": "Initial"},
        )
        second = client.post(
            f"/v1/requests/{request_id}/bids",
            headers=auth(provider_user["access_token"]),
            json={"amount_paise": 31500, "note": "Revised"},
        )
        assert first.status_code == 201
        assert second.status_code == 201
        assert second.json()["previous_bid_event_id"] == first.json()["id"]
        history = client.get(f"/v1/requests/{request_id}/bids")
        assert history.status_code == 200
        events = history.json()
        assert [event["amount_paise"] for event in events] == [31500, 34900]
        assert events[0]["is_current_offer"] is True
        assert events[1]["is_current_offer"] is False
        historical_award = client.post(
            f"/v1/requests/{request_id}/award/{first.json()['id']}",
            headers=auth(customer["access_token"]),
        )
        assert historical_award.status_code == 409
        booking = client.post(
            f"/v1/requests/{request_id}/award/{second.json()['id']}",
            headers=auth(customer["access_token"]),
        )
        assert booking.status_code == 201, booking.text
        booked = booking.json()
        assert booked["accepted_bid_event_id"] == second.json()["id"]
        assert booked["agreed_amount_paise"] == 31500
        double_award = client.post(
            f"/v1/requests/{request_id}/award/{second.json()['id']}",
            headers=auth(customer["access_token"]),
        )
        assert double_award.status_code == 409


def test_group_vote_publish_creates_biddable_request() -> None:
    with TestClient(app) as client:
        admin = login(client, "9876500021")
        member = login(client, "9876500022")
        group = client.post(
            "/v1/groups",
            headers=auth(admin["access_token"]),
            json={"name": "Green Residency", "area": "Sector 15, Sonipat"},
        )
        assert group.status_code == 201, group.text
        group_data = group.json()
        joined = client.post(
            "/v1/groups/join",
            headers=auth(member["access_token"]),
            json={"invite_code": group_data["invite_code"]},
        )
        assert joined.status_code == 201
        proposal = client.post(
            f"/v1/groups/{group_data['id']}/proposals",
            headers=auth(admin["access_token"]),
            json={
                "title": "Bulk AC servicing",
                "category": "AC Service",
                "description": "Indoor and outdoor cleaning",
                "preferred_for": "2026-09-12T09:00:00+05:30",
            },
        )
        assert proposal.status_code == 201
        proposal_id = proposal.json()["id"]
        voted = client.put(
            f"/v1/groups/{group_data['id']}/proposals/{proposal_id}/vote",
            headers=auth(member["access_token"]),
            json={"choice": "accept", "quantity": 3},
        )
        assert voted.status_code == 200
        summary = client.get(
            f"/v1/groups/{group_data['id']}/proposals/{proposal_id}/summary",
            headers=auth(admin["access_token"]),
        )
        assert summary.status_code == 200
        assert summary.json()["accept_count"] == 1
        assert summary.json()["accepted_quantity"] == 3
        published = client.post(
            f"/v1/groups/{group_data['id']}/proposals/{proposal_id}/publish",
            headers=auth(admin["access_token"]),
        )
        assert published.status_code == 201, published.text
        result = published.json()
        assert result["group_id"] == group_data["id"]
        assert result["status"] == "bidding"
        assert "Group accepted quantity: 3" in result["description"]
