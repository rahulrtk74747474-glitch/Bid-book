from __future__ import annotations

from fastapi.testclient import TestClient

from app.main import app


def _login(client: TestClient, phone: str) -> dict[str, str]:
    requested = client.post("/v1/auth/otp/request", json={"phone": phone})
    assert requested.status_code == 201, requested.text
    challenge = requested.json()
    verified = client.post(
        "/v1/auth/otp/verify",
        json={
            "challenge_id": challenge["challenge_id"],
            "otp": challenge["development_otp"],
            "device_id": "media-test-device",
        },
    )
    assert verified.status_code == 200, verified.text
    return verified.json()


def test_request_photo_upload_and_public_gallery() -> None:
    with TestClient(app) as client:
        session = _login(client, "9876500091")
        headers = {"Authorization": f"Bearer {session['access_token']}"}
        request = client.post(
            "/v1/requests",
            headers=headers,
            json={
                "title": "Repair leaking tap",
                "category": "Plumber",
                "description": "Kitchen tap needs repair",
                "area": "Sector 15, Sonipat",
                "requested_for": "2026-10-10T10:00:00+05:30",
            },
        )
        assert request.status_code == 201, request.text
        request_id = request.json()["id"]

        payload = b"not-a-real-png-but-safe-test-bytes"
        intent = client.post(
            "/v1/ops/media/intents",
            headers=headers,
            json={
                "entity_type": "request",
                "entity_id": request_id,
                "content_type": "image/png",
                "size_bytes": len(payload),
            },
        )
        assert intent.status_code == 201, intent.text
        media_id = intent.json()["id"]

        uploaded = client.put(
            f"/v1/ops/media/{media_id}/content",
            headers={**headers, "Content-Type": "image/png"},
            content=payload,
        )
        assert uploaded.status_code == 200, uploaded.text
        assert uploaded.json()["status"] == "ready"

        gallery = client.get(f"/v1/ops/media/gallery/request/{request_id}")
        assert gallery.status_code == 200, gallery.text
        assert gallery.json() == [f"/v1/ops/media/public/{media_id}"]

        public = client.get(f"/v1/ops/media/public/{media_id}")
        assert public.status_code == 200
        assert public.content == payload
        assert public.headers["content-type"].startswith("image/png")
