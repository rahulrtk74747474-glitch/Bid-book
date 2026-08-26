#!/usr/bin/env bash
set -euo pipefail

API_URL="${1:-${BIDBOOK_API_BASE_URL:-}}"
MODE="${BUILD_MODE:-debug}"
GOOGLE_SERVER_CLIENT_ID="${BIDBOOK_GOOGLE_SERVER_CLIENT_ID:-}"

if [ -z "$API_URL" ]; then
  echo "Usage: bash tools/build_android_apk.sh https://your-api.example.com"
  echo "or set BIDBOOK_API_BASE_URL first."
  exit 2
fi

# This repository intentionally keeps native platform scaffolding out of source.
# Generate a clean Android shell when needed without overwriting the existing
# Bid&Book Flutter source files.
if [ ! -d android ]; then
  echo "Android scaffold not found. Generating it now..."
  tmpdir="$(mktemp -d)"
  flutter create "$tmpdir/bid_book_android" \
    --platforms=android \
    --org com.bidbook \
    --project-name bid_book
  cp -R "$tmpdir/bid_book_android/android" ./android
  rm -rf "$tmpdir"
fi

flutter pub get
flutter analyze
flutter test

DART_DEFINES=(--dart-define="BIDBOOK_API_BASE_URL=$API_URL")
if [ -n "$GOOGLE_SERVER_CLIENT_ID" ]; then
  DART_DEFINES+=(--dart-define="BIDBOOK_GOOGLE_SERVER_CLIENT_ID=$GOOGLE_SERVER_CLIENT_ID")
  echo "Google server client ID is included in this build."
else
  echo "Google server client ID is not set; Google sign-in will remain disabled."
fi

if [ "$MODE" = "release" ]; then
  flutter build apk --release "${DART_DEFINES[@]}"
  src="build/app/outputs/flutter-apk/app-release.apk"
else
  flutter build apk --debug "${DART_DEFINES[@]}"
  src="build/app/outputs/flutter-apk/app-debug.apk"
fi

mkdir -p dist
cp "$src" "dist/BidBook-Professional-Trust-${MODE}.apk"
sha256sum "dist/BidBook-Professional-Trust-${MODE}.apk"
echo
echo "APK ready: dist/BidBook-Professional-Trust-${MODE}.apk"
