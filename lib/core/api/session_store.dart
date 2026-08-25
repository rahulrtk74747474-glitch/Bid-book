import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore());

class SessionStore {
  SessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _accessKey = 'bidbook_access_token_v1';
  static const _refreshKey = 'bidbook_refresh_token_v1';
  static const _deviceKey = 'bidbook_device_id_v1';

  final FlutterSecureStorage _storage;
  bool _loaded = false;
  String? _accessToken;
  String? _refreshToken;
  String? _deviceId;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  bool get hasSession => _refreshToken?.isNotEmpty == true;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final values = await Future.wait([
      _storage.read(key: _accessKey),
      _storage.read(key: _refreshKey),
      _storage.read(key: _deviceKey),
    ]);
    _accessToken = values[0];
    _refreshToken = values[1];
    _deviceId = values[2];
    _loaded = true;
  }

  Future<String> deviceId() async {
    await ensureLoaded();
    final existing = _deviceId;
    if (existing != null && existing.isNotEmpty) return existing;
    final value = const Uuid().v4();
    _deviceId = value;
    await _storage.write(key: _deviceKey, value: value);
    return value;
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _loaded = true;
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    await Future.wait([
      _storage.write(key: _accessKey, value: accessToken),
      _storage.write(key: _refreshKey, value: refreshToken),
    ]);
  }

  Future<void> clearTokens() async {
    _loaded = true;
    _accessToken = null;
    _refreshToken = null;
    await Future.wait([
      _storage.delete(key: _accessKey),
      _storage.delete(key: _refreshKey),
    ]);
  }
}
