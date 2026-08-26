from __future__ import annotations

from fastapi.testclient import TestClient

from app.main import app
from app.routers import auth as auth_router


def test_email_create_account_and_login() -> None:
    with TestClient(app) as client:
        registered = client.post(
            "/v1/auth/email/register",
            json={
                "display_name": "Aarav Test",
                "email": "Aarav.Test@Example.com",
                "password": "strong-test-password-123",
                "device_id": "email-register-test",
            },
        )
        assert registered.status_code == 201, registered.text
        body = registered.json()
        assert body["user"]["email"] == "aarav.test@example.com"
        assert body["user"]["phone"] is None
        assert body["user"]["display_name"] == "Aarav Test"
        assert body["user"]["email_verified"] is False
        assert body["access_token"]
        assert body["refresh_token"]

        duplicate = client.post(
            "/v1/auth/email/register",
            json={
                "display_name": "Duplicate",
                "email": "aarav.test@example.com",
                "password": "another-password-123",
            },
        )
        assert duplicate.status_code == 409

        wrong = client.post(
            "/v1/auth/email/login",
            json={"email": "aarav.test@example.com", "password": "wrong-password"},
        )
        assert wrong.status_code == 401

        logged_in = client.post(
            "/v1/auth/email/login",
            json={
                "email": "AARAV.TEST@example.com",
                "password": "strong-test-password-123",
                "device_id": "email-login-test",
            },
        )
        assert logged_in.status_code == 200, logged_in.text
        assert logged_in.json()["user"]["id"] == body["user"]["id"]


def test_google_sign_in_creates_and_reuses_account(monkeypatch) -> None:
    async def fake_verify(_: str) -> dict[str, object]:
        return {
            "sub": "google-user-123",
            "email": "google.user@example.com",
            "email_verified": True,
            "name": "Google Test User",
            "picture": "https://example.com/avatar.png",
        }

    monkeypatch.setattr(auth_router, "verify_google_token", fake_verify)

    with TestClient(app) as client:
        first = client.post(
            "/v1/auth/google",
            json={"id_token": "fake-google-id-token-for-tests", "device_id": "google-one"},
        )
        assert first.status_code == 200, first.text
        first_body = first.json()
        assert first_body["user"]["email"] == "google.user@example.com"
        assert first_body["user"]["email_verified"] is True
        assert first_body["user"]["display_name"] == "Google Test User"
        assert first_body["user"]["avatar_url"] == "https://example.com/avatar.png"

        second = client.post(
            "/v1/auth/google",
            json={"id_token": "fake-google-id-token-for-tests", "device_id": "google-two"},
        )
        assert second.status_code == 200, second.text
        assert second.json()["user"]["id"] == first_body["user"]["id"]
