#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is not installed or not on PATH."
  exit 1
fi

if [[ ! -d android || ! -d ios ]]; then
  flutter create . --platforms=android,ios --org com.bidbook --project-name bid_book
fi

python3 tools/configure_mobile_native.py
flutter pub get
flutter analyze
flutter test

echo "Bid&Book mobile wrappers are ready."
echo "Android package / iOS bundle ID: com.bidbook.app"
echo "Run: flutter run --dart-define=BIDBOOK_API_BASE_URL=http://<your-lan-ip>:8000"
