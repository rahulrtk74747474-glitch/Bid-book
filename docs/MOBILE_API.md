# Mobile ↔ API integration

The production Flutter navigation now uses the persistent FastAPI backend rather than the seeded in-memory demo controllers.

## API URL

Development defaults:

- Android emulator: `http://10.0.2.2:8000`
- iOS simulator / desktop test host: `http://127.0.0.1:8000`

For a physical phone or hosted environment, supply the API explicitly:

```bash
flutter run --dart-define=BIDBOOK_API_BASE_URL=http://192.168.1.50:8000
```

Release builds fail closed unless `BIDBOOK_API_BASE_URL` is provided and uses HTTPS:

```bash
flutter build apk --release \
  --dart-define=BIDBOOK_API_BASE_URL=https://api.example.com
```

Never ship a production mobile build pointed at plain HTTP.

## Session security

- Access and refresh tokens are stored with `flutter_secure_storage`.
- Android uses the package's RSA-OAEP + AES-GCM secure-storage path.
- The chosen 10.2.x line targets Android SDK 36 and provides the migration bridge to the newer cipher defaults.
- Access tokens are attached only to authenticated requests.
- A 401 triggers one refresh-token rotation and one retry.
- Concurrent refresh attempts share one refresh operation.
- Refresh failure clears local tokens and forces re-authentication.
- Logout revokes the server session when reachable, then clears device tokens regardless of network state.
- A generated device ID is kept in secure storage and sent when establishing the OTP session.

## Production data path

The active mobile screens now load and mutate the API for:

- OTP authentication and session restore
- provider profile
- service catalog and direct bookings
- service requests
- append-only bids and rebids
- exact current-bid award
- booking history
- neighborhood groups
- group proposals, voting quantities and summaries
- publishing a group proposal into the public bidding marketplace

The older in-memory controllers remain only to preserve isolated domain/unit tests for bidding invariants. Production routing does not depend on those seeded records.

## Native project note

The repository intentionally generates `android/` and `ios/` with `flutter create .` during first local bootstrap. For Android secure storage, keep the generated app at API 23+; Flutter/secure-storage 10.2 targets SDK 36. Before store release, disable Android backup for the secure-storage namespace as recommended by the plugin documentation and commit the finalized native folders/settings.
