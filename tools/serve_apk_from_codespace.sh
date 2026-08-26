#!/usr/bin/env bash
set -euo pipefail

APK="${1:-dist/BidBook-Professional-Trust-debug.apk}"
if [ ! -f "$APK" ]; then
  echo "APK not found: $APK"
  echo "Build it first with tools/build_android_apk.sh"
  exit 2
fi

mkdir -p dist-download
cp "$APK" dist-download/BidBook.apk
pkill -f 'http.server 8080' 2>/dev/null || true
nohup python3 -m http.server 8080 --directory dist-download >/tmp/bidbook-apk-server.log 2>&1 &
sleep 2

if [ -n "${CODESPACE_NAME:-}" ]; then
  echo "Make port 8080 Public in the Codespaces PORTS tab."
  echo "Then download the APK on your phone from:"
  echo "https://${CODESPACE_NAME}-8080.app.github.dev/BidBook.apk"
else
  echo "APK server is running on port 8080. Expose that port publicly and open /BidBook.apk."
fi
