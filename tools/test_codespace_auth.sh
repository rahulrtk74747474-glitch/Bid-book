#!/usr/bin/env bash
set -euo pipefail

API_ROOT="${1:-http://127.0.0.1:8000/v1}"
STAMP="$(date +%s)"
PHONE="98765${STAMP: -5}"
EMAIL="codespace-auth-${STAMP}@example.com"
PASSWORD="BidBook-Test-${STAMP}!"

printf 'Testing Bid&Book auth at %s\n' "$API_ROOT"

request_payload="$(jq -nc --arg phone "$PHONE" '{phone:$phone}')"
request_response="$(curl -fsS -X POST "$API_ROOT/auth/otp/request" -H 'content-type: application/json' -d "$request_payload")"
challenge_id="$(printf '%s' "$request_response" | jq -r '.challenge_id')"
otp="$(printf '%s' "$request_response" | jq -r '.development_otp // empty')"

if [ -z "$challenge_id" ] || [ -z "$otp" ]; then
  echo 'OTP request did not return a development OTP.' >&2
  printf '%s\n' "$request_response" >&2
  exit 1
fi

verify_payload="$(jq -nc --arg challenge "$challenge_id" --arg otp "$otp" '{challenge_id:$challenge,otp:$otp,device_id:"codespace-smoke"}')"
verify_response="$(curl -fsS -X POST "$API_ROOT/auth/otp/verify" -H 'content-type: application/json' -d "$verify_payload")"
printf '%s' "$verify_response" | jq -e '.access_token and .refresh_token and .user.phone' >/dev/null
echo 'PASS: phone OTP request + verification'

register_payload="$(jq -nc --arg name 'Codespace Auth Test' --arg email "$EMAIL" --arg password "$PASSWORD" '{display_name:$name,email:$email,password:$password,device_id:"codespace-email-register"}')"
register_response="$(curl -fsS -X POST "$API_ROOT/auth/email/register" -H 'content-type: application/json' -d "$register_payload")"
printf '%s' "$register_response" | jq -e --arg email "$EMAIL" '.access_token and .refresh_token and (.user.email == $email)' >/dev/null
echo 'PASS: email account creation'

login_payload="$(jq -nc --arg email "$EMAIL" --arg password "$PASSWORD" '{email:$email,password:$password,device_id:"codespace-email-login"}')"
login_response="$(curl -fsS -X POST "$API_ROOT/auth/email/login" -H 'content-type: application/json' -d "$login_payload")"
printf '%s' "$login_response" | jq -e --arg email "$EMAIL" '.access_token and .refresh_token and (.user.email == $email)' >/dev/null
echo 'PASS: email/password login'

echo
echo 'Bid&Book Codespaces auth smoke test passed.'
