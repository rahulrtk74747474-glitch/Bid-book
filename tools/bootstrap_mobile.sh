#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is not installed or not on PATH."
  exit 1
fi

if [[ ! -d android || ! -d ios ]]; then
  flutter create . --platforms=android,ios --org com.bidbook --project-name bid_book
fi

flutter pub get
flutter test

echo "Bid&Book is ready. Run: flutter run"
