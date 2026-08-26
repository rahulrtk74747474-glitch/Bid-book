#!/usr/bin/env bash
set -euo pipefail

export ENVIRONMENT=development
export DATABASE_URL="sqlite+aiosqlite:///$PWD/backend/bidbook-codespace.db"
export JWT_SECRET="codespace-test-only-change-before-production-$(printf '%032d' 1)"
export OTP_PEPPER="codespace-test-only-otp-pepper-$(printf '%032d' 2)"
export EXPOSE_DEVELOPMENT_OTP=true
export AUTO_CREATE_TABLES=true
export OTP_COOLDOWN_SECONDS=0
export OTP_HOURLY_LIMIT=100
export PLATFORM_FEE_BPS=0

if [ -n "${BIDBOOK_GOOGLE_SERVER_CLIENT_ID:-}" ] && [ -z "${GOOGLE_OAUTH_CLIENT_ID:-}" ]; then
  export GOOGLE_OAUTH_CLIENT_ID="$BIDBOOK_GOOGLE_SERVER_CLIENT_ID"
fi

if [ -f .venv/bin/activate ]; then
  . .venv/bin/activate
fi

python -m pip install -q aiosqlite >/dev/null

pkill -f 'uvicorn app.main:app.*8000' 2>/dev/null || true
nohup bash -lc 'cd backend && python -m uvicorn app.main:app --host 0.0.0.0 --port 8000' > /tmp/bidbook-api.log 2>&1 &

for i in $(seq 1 60); do
  if curl -fsS http://127.0.0.1:8000/health >/dev/null; then
    break
  fi
  sleep 1
  if [ "$i" -eq 60 ]; then
    cat /tmp/bidbook-api.log
    exit 1
  fi
done

echo "Bid&Book test backend is running on port 8000."
if [ -n "${GOOGLE_OAUTH_CLIENT_ID:-}" ]; then
  echo "Google OAuth verification is configured for this backend."
else
  echo "Google OAuth client ID is not set; Google sign-in is disabled for this test backend."
fi

if [ -n "${CODESPACE_NAME:-}" ]; then
  PUBLIC_URL="https://${CODESPACE_NAME}-8000.app.github.dev"
  echo "Expected Codespaces URL: $PUBLIC_URL"
  echo "Make port 8000 Public in the Codespaces PORTS tab before building the APK."
  echo "Then run:"
  echo "  bash tools/build_android_apk.sh $PUBLIC_URL"
else
  echo "Expose port 8000 publicly, then pass that HTTPS URL to tools/build_android_apk.sh."
fi
