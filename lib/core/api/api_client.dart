import 'dart:async';

import 'package:bid_book/core/api/api_config.dart';
import 'package:bid_book/core/api/api_exception.dart';
import 'package:bid_book/core/api/session_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(ref.read(sessionStoreProvider));
  ref.onDispose(client.dispose);
  return client;
});

class ApiClient {
  ApiClient(this._sessionStore)
      : _dio = Dio(_options()),
        _refreshDio = Dio(_options());

  final SessionStore _sessionStore;
  final Dio _dio;
  final Dio _refreshDio;
  final _expiredController = StreamController<void>.broadcast();
  Future<void>? _refreshFuture;

  Stream<void> get sessionExpired => _expiredController.stream;

  static BaseOptions _options() => BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 40),
        receiveTimeout: const Duration(seconds: 40),
        responseType: ResponseType.json,
        headers: const {'Accept': 'application/json'},
      );

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    bool authenticated = true,
    Map<String, dynamic>? headers,
  }) =>
      _send('GET', path, query: query, authenticated: authenticated, headers: headers);

  Future<dynamic> post(
    String path, {
    Object? data,
    bool authenticated = true,
    Map<String, dynamic>? headers,
  }) =>
      _send('POST', path, data: data, authenticated: authenticated, headers: headers);

  Future<dynamic> put(
    String path, {
    Object? data,
    bool authenticated = true,
    Map<String, dynamic>? headers,
  }) =>
      _send('PUT', path, data: data, authenticated: authenticated, headers: headers);

  Future<dynamic> delete(
    String path, {
    Object? data,
    bool authenticated = true,
    Map<String, dynamic>? headers,
  }) =>
      _send('DELETE', path, data: data, authenticated: authenticated, headers: headers);

  Future<dynamic> _send(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    bool authenticated = true,
    bool allowRefresh = true,
    Map<String, dynamic>? headers,
  }) async {
    await _sessionStore.ensureLoaded();
    final requestHeaders = <String, dynamic>{...?headers};
    final accessToken = _sessionStore.accessToken;
    if (authenticated && accessToken != null) {
      requestHeaders['Authorization'] = 'Bearer $accessToken';
    }

    try {
      final response = await _dio.request<dynamic>(
        path,
        data: data,
        queryParameters: query,
        options: Options(method: method, headers: requestHeaders),
      );
      return response.data;
    } on DioException catch (error) {
      if (authenticated &&
          allowRefresh &&
          error.response?.statusCode == 401 &&
          _sessionStore.refreshToken != null) {
        await _refreshTokens();
        return _send(
          method,
          path,
          data: data,
          query: query,
          authenticated: authenticated,
          allowRefresh: false,
          headers: headers,
        );
      }
      throw ApiException.fromDio(error);
    }
  }

  Future<void> _refreshTokens() async {
    final existing = _refreshFuture;
    if (existing != null) return existing;

    final completer = Completer<void>();
    _refreshFuture = completer.future;
    try {
      final refreshToken = _sessionStore.refreshToken;
      if (refreshToken == null) throw const ApiException('Session expired.');
      final response = await _refreshDio.post<dynamic>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final data = _asMap(response.data);
      await _sessionStore.saveTokens(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
      );
      completer.complete();
    } on DioException catch (error) {
      await _expireSession();
      final exception = ApiException.fromDio(error);
      completer.completeError(exception);
      throw exception;
    } catch (error) {
      await _expireSession();
      if (!completer.isCompleted) completer.completeError(error);
      rethrow;
    } finally {
      _refreshFuture = null;
    }
  }

  Future<void> _expireSession() async {
    await _sessionStore.clearTokens();
    if (!_expiredController.isClosed) _expiredController.add(null);
  }

  void dispose() {
    _dio.close(force: true);
    _refreshDio.close(force: true);
    _expiredController.close();
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, item) => MapEntry('$key', item));
  throw const ApiException('The server returned an unexpected response.');
}
