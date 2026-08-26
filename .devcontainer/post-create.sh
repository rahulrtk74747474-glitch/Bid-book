#!/usr/bin/env bash
set -euo pipefail

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  curl unzip xz-utils zip libglu1-mesa ca-certificates \
  openjdk-17-jdk python3 python3-pip python3-venv jq

# Flutter stable
if [ ! -d /opt/flutter/.git ]; then
  sudo git clone --depth 1 --branch stable https://github.com/flutter/flutter.git /opt/flutter
  sudo chown -R "$(id -u):$(id -g)" /opt/flutter
fi

# Android command-line SDK
sudo mkdir -p /opt/android-sdk/cmdline-tools
sudo chown -R "$(id -u):$(id -g)" /opt/android-sdk
if [ ! -x /opt/android-sdk/cmdline-tools/latest/bin/sdkmanager ]; then
  tmpdir="$(mktemp -d)"
  curl -fL --retry 3 -o "$tmpdir/cmdline-tools.zip" \
    https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
  unzip -q "$tmpdir/cmdline-tools.zip" -d "$tmpdir"
  mkdir -p /opt/android-sdk/cmdline-tools/latest
  mv "$tmpdir/cmdline-tools/"* /opt/android-sdk/cmdline-tools/latest/
  rm -rf "$tmpdir"
fi

export JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")"
export ANDROID_SDK_ROOT=/opt/android-sdk
export ANDROID_HOME=/opt/android-sdk
export PATH="/opt/flutter/bin:/opt/android-sdk/cmdline-tools/latest/bin:/opt/android-sdk/platform-tools:$PATH"

yes | sdkmanager --licenses >/dev/null || true
sdkmanager \
  "platform-tools" \
  "platforms;android-35" \
  "build-tools;35.0.0"

flutter config --android-sdk /opt/android-sdk
flutter config --no-analytics
flutter precache --android
flutter pub get

# Backend development dependencies
python3 -m venv .venv
. .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -e './backend[dev]' || python -m pip install -e ./backend

deactivate

# Prime Agent stable installer (official Prime Intellect installer)
curl -fsSL https://app.primeintellect.ai/prime-agent/install.sh | sh

# Make installed user binaries and project tools available in new shells.
cat <<'EOF' >> "$HOME/.bashrc"
export FLUTTER_HOME=/opt/flutter
export ANDROID_SDK_ROOT=/opt/android-sdk
export ANDROID_HOME=/opt/android-sdk
export PATH="$HOME/.local/bin:$HOME/bin:/opt/flutter/bin:/opt/android-sdk/cmdline-tools/latest/bin:/opt/android-sdk/platform-tools:$PATH"
EOF

printf '\nBid&Book cloud environment is ready.\n'
printf 'Next: prime-agent\n'
printf 'Then inside Prime Agent run /login and give it PRIME_AGENT_MISSION.md.\n\n'
flutter doctor -v || true
prime-agent doctor --fix || true
