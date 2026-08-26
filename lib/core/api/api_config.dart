import 'dart:io';

import 'package:flutter/foundation.dart';

class ApiConfig {
  ApiConfig._();

  static const _definedBaseUrl = String.fromEnvironment('BIDBOOK_API_BASE_URL');

  static String get serverRoot {
    final configured = _definedBaseUrl.trim();
    if (configured.isNotEmpty) {
      _validateReleaseUrl(configured);
      var value = _stripTrailingSlash(configured);
      if (value.endsWith('/v1')) value = value.substring(0, value.length - 3);
      return _stripTrailingSlash(value);
    }
    if (kReleaseMode) {
      throw StateError(
        'BIDBOOK_API_BASE_URL must be supplied with --dart-define and use HTTPS for release builds.',
      );
    }
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://127.0.0.1:8000';
  }

  static String get baseUrl => '$serverRoot/v1';

  static String absoluteUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('https://') || trimmed.startsWith('http://')) return trimmed;
    return trimmed.startsWith('/') ? '$serverRoot$trimmed' : '$serverRoot/$trimmed';
  }

  static void _validateReleaseUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw StateError('BIDBOOK_API_BASE_URL is not a valid absolute URL.');
    }
    if (kReleaseMode && uri.scheme.toLowerCase() != 'https') {
      throw StateError('Release builds require an HTTPS Bid&Book API URL.');
    }
  }

  static String _stripTrailingSlash(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}
