# Bid&Book — Phone-only Prime Agent + APK workflow

This setup is designed for working from an Android phone without a local PC.

## 1. Create the cloud development machine

Open this while signed in to GitHub:

https://github.com/codespaces/new?hide_repo_select=true&ref=prime-agent-cloud-dev&repo=1345296708&skip_quickstart=true

Choose a machine with at least 4 cores / 8 GB RAM, then create the Codespace.

The repository's `.devcontainer` automatically installs:
- Flutter stable
- Android command-line SDK + platform/build tools
- Java 17
- Python/backend tooling
- GitHub CLI
- Prime Agent using Prime Intellect's official installer

The first Codespace creation can take several minutes because Flutter and Android SDK packages must download.

## 2. Start Prime Agent

Open the Codespaces terminal and run:

```bash
prime-agent
```

On first launch, use:

```text
/login
```

Choose your Prime Intellect subscription or supported API-key provider.

Then tell Prime Agent:

```text
Read PRIME_AGENT_MISSION.md completely. Treat every rule in it as mandatory. Inspect this repository, report the current state, and start with the highest-priority incomplete item. Never weaken or replace the append-only bid/rebid history invariant.
```

Prime Agent executes commands with the Codespace user's permissions. Review its commits before merging them into `main`.

## 3. Start a temporary phone-test backend

In another terminal:

```bash
bash tools/start_codespace_test_backend.sh
```

In the Codespaces **PORTS** tab, find port **8000**, change its visibility to **Public**, and copy its HTTPS URL.

The usual URL format is:

```text
https://<CODESPACE_NAME>-8000.app.github.dev
```

This is a development/test backend only. Do not treat these generated test secrets or the SQLite database as production infrastructure.

## 4. Build the Android APK

Pass the public backend URL to:

```bash
bash tools/build_android_apk.sh https://<CODESPACE_NAME>-8000.app.github.dev
```

The script runs:
- `flutter pub get`
- `flutter analyze`
- `flutter test`
- Android APK build

When successful, the APK is written to:

```text
dist/BidBook-Professional-Trust-debug.apk
```

For a release-mode test build:

```bash
BUILD_MODE=release bash tools/build_android_apk.sh https://<CODESPACE_NAME>-8000.app.github.dev
```

## 5. Download the APK directly to the Android phone

Run:

```bash
bash tools/serve_apk_from_codespace.sh
```

In the **PORTS** tab make port **8080** Public.

Then open this URL on the phone:

```text
https://<CODESPACE_NAME>-8080.app.github.dev/BidBook.apk
```

Android will download the APK.

Then:
1. Open **Files / Downloads**.
2. Tap `BidBook.apk`.
3. If Android blocks installation, choose **Settings → Allow from this source**.
4. Return and choose **Install**.

## Important production limitations

This workflow is for development/testing. Production release still requires real infrastructure and credentials, including production database/storage, SMS/DLT, Google OAuth client configuration, payment/KYC providers where used, Android signing/Play Console configuration, and legal/security review.
