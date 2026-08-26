#!/usr/bin/env bash
set -euo pipefail

API_URL="${1:-${BIDBOOK_API_BASE_URL:-}}"
MODE="${BUILD_MODE:-debug}"

if [ -z "$API_URL" ]; then
  echo "Usage: bash tools/build_android_apk.sh https://your-api.example.com"
  echo "or set BIDBOOK_API_BASE_URL first."
  exit 2
fi

flutter pub get
flutter analyze
flutter test

if [ "$MODE" = "release" ]; then
  flutter build apk --release --dart-define="BIDBOOK_API_BASE_URL=$API_URL"
  src="build/app/outputs/flutter-apk/app-release.apk"
else
  flutter build apk --debug --dart-define="BIDBOOK_API_BASE_URL=$API_URL"
  src="build/app/outputs/flutter-apk/app-debug.apk"
fi

mkdir -p dist
cp "$src" "dist/BidBook-Professional-Trust-${MODE}.apk"
sha256sum "dist/BidBook-Professional-Trust-${MODE}.apk"
echo
echo "APK ready: dist/BidBook-Professional-Trust-${MODE}.apk"
