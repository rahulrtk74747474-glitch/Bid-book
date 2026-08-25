import 'dart:io';

import 'package:bid_book/core/api/api_client.dart';
import 'package:bid_book/core/api/session_store.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class PushRegistrationService {
  PushRegistrationService(this._apiClient, this._sessionStore);

  final ApiClient _apiClient;
  final SessionStore _sessionStore;
  bool _initialized = false;

  Future<bool> initializeAndRegister() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      final messaging = FirebaseMessaging.instance;
      final permission = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      if (permission.authorizationStatus == AuthorizationStatus.denied) {
        return false;
      }
      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return false;
      await _registerToken(token);
      if (!_initialized) {
        _initialized = true;
        messaging.onTokenRefresh.listen((newToken) async {
          try {
            await _registerToken(newToken);
          } catch (_) {
            // The in-app notification inbox remains available if token refresh
            // registration is temporarily offline.
          }
        });
      }
      return true;
    } catch (_) {
      // Firebase native configuration is supplied outside source control.
      // Missing configuration must never prevent users from opening the app.
      return false;
    }
  }

  Future<void> _registerToken(String token) async {
    final deviceId = await _sessionStore.deviceId();
    await _apiClient.put('/communications/push-token', data: {
      'device_id': deviceId,
      'platform': Platform.isIOS ? 'ios' : 'android',
      'token': token,
    });
  }
}
