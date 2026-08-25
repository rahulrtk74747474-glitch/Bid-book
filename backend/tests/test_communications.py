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
            "device_id": f"test-{phone}",
        },
    )
    assert verified.status_code == 200, verified.text
    return verified.json()


def auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def test_notifications_and_booking_chat_are_authorized() -> None:
    with TestClient(app) as client:
        customer = login(client, "9876500101")
        provider_user = login(client, "9876500102")
        stranger = login(client, "9876500103")

        provider = client.put(
            "/v1/providers/me",
            headers=auth(provider_user["access_token"]),
            json={
                "kind": "individual",
                "display_name": "NotifyFix",
                "service_area": "Sonipat",
                "bio": "Test provider",
            },
        )
        assert provider.status_code == 200, provider.text

        push = client.put(
            "/v1/communications/push-token",
            headers=auth(provider_user["access_token"]),
            json={
                "device_id": "provider-phone-1",
                "platform": "android",
                "token": "fcm-test-token-that-is-long-enough-0001",
            },
        )
        assert push.status_code == 200, push.text

        request = client.post(
            "/v1/requests",
            headers=auth(customer["access_token"]),
            json={
                "title": "AC service with chat",
                "category": "AC Service",
                "description": "Need service and coordination",
                "area": "Sector 15, Sonipat",
                "requested_for": "2026-09-20T09:00:00+05:30",
            },
        )
        assert request.status_code == 201, request.text
        request_id = request.json()["id"]

        bid = client.post(
            f"/v1/requests/{request_id}/bids",
            headers=auth(provider_user["access_token"]),
            json={"amount_paise": 42000, "note": "Includes cleaning"},
        )
        assert bid.status_code == 201, bid.text

        customer_notifications = client.get(
            "/v1/communications/notifications?unread_only=true",
            headers=auth(customer["access_token"]),
        )
        assert customer_notifications.status_code == 200
        bid_notice = next(item for item in customer_notifications.json() if item["kind"] == "bid_received")
        assert bid_notice["entity_id"] == request_id

        read = client.post(
            f"/v1/communications/notifications/{bid_notice['id']}/read",
            headers=auth(customer["access_token"]),
        )
        assert read.status_code == 200
        assert read.json()["read_at"] is not None

        award = client.post(
            f"/v1/requests/{request_id}/award/{bid.json()['id']}",
            headers=auth(customer["access_token"]),
        )
        assert award.status_code == 201, award.text
        booking_id = award.json()["id"]

        provider_notifications = client.get(
            "/v1/communications/notifications?unread_only=true",
            headers=auth(provider_user["access_token"]),
        )
        assert provider_notifications.status_code == 200
        assert any(item["kind"] == "bid_accepted" for item in provider_notifications.json())

        chat = client.post(
            f"/v1/communications/chats/from-booking/{booking_id}",
            headers=auth(customer["access_token"]),
        )
        assert chat.status_code == 200, chat.text
        chat_id = chat.json()["id"]

        forbidden = client.get(
            f"/v1/communications/chats/{chat_id}/messages",
            headers=auth(stranger["access_token"]),
        )
        assert forbidden.status_code == 403

        sent = client.post(
            f"/v1/communications/chats/{chat_id}/messages",
            headers=auth(customer["access_token"]),
            json={"body": "Please call when you reach the gate."},
        )
        assert sent.status_code == 201, sent.text

        provider_chats = client.get(
            "/v1/communications/chats",
            headers=auth(provider_user["access_token"]),
        )
        assert provider_chats.status_code == 200
        thread = next(item for item in provider_chats.json() if item["id"] == chat_id)
        assert thread["unread_count"] == 1

        messages = client.get(
            f"/v1/communications/chats/{chat_id}/messages",
            headers=auth(provider_user["access_token"]),
        )
        assert messages.status_code == 200
        assert messages.json()[-1]["body"] == "Please call when you reach the gate."

        after_read = client.get(
            "/v1/communications/chats",
            headers=auth(provider_user["access_token"]),
        )
        thread_after_read = next(item for item in after_read.json() if item["id"] == chat_id)
        assert thread_after_read["unread_count"] == 0

        message_notices = client.get(
            "/v1/communications/notifications",
            headers=auth(provider_user["access_token"]),
        )
        assert any(item["kind"] == "chat_message" and item["entity_id"] == chat_id for item in message_notices.json())
