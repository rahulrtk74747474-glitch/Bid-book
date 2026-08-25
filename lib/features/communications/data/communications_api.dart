import 'package:bid_book/core/api/api_client.dart';
import 'package:bid_book/core/api/api_exception.dart';
import 'package:bid_book/features/communications/domain/communication_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final communicationsApiProvider = Provider<CommunicationsApi>(
  (ref) => CommunicationsApi(ref.read(apiClientProvider)),
);

class CommunicationsApi {
  const CommunicationsApi(this._client);

  final ApiClient _client;

  Future<List<ApiNotification>> notifications({bool unreadOnly = false}) async {
    final data = await _client.get('/communications/notifications', query: {
      'unread_only': unreadOnly,
      'limit': 200,
    });
    return _list(data).map(ApiNotification.fromJson).toList(growable: false);
  }

  Future<int> unreadNotificationCount() async {
    final data = _map(await _client.get('/communications/notifications/unread-count'));
    return data['count'] as int? ?? 0;
  }

  Future<void> markNotificationRead(String id) async {
    await _client.post('/communications/notifications/$id/read');
  }

  Future<void> markAllNotificationsRead() async {
    await _client.post('/communications/notifications/read-all');
  }

  Future<List<ApiChatThread>> chats() async {
    final data = await _client.get('/communications/chats');
    return _list(data).map(ApiChatThread.fromJson).toList(growable: false);
  }

  Future<ApiChatThread> chatFromBooking(String bookingId) async =>
      ApiChatThread.fromJson(
        _map(await _client.post('/communications/chats/from-booking/$bookingId')),
      );

  Future<List<ApiChatMessage>> chatMessages(String chatId) async {
    final data = await _client.get('/communications/chats/$chatId/messages', query: {
      'limit': 200,
    });
    return _list(data).map(ApiChatMessage.fromJson).toList(growable: false);
  }

  Future<ApiChatMessage> sendChatMessage({
    required String chatId,
    required String body,
  }) async =>
      ApiChatMessage.fromJson(
        _map(await _client.post(
          '/communications/chats/$chatId/messages',
          data: {'body': body},
        )),
      );

  Future<void> registerPushToken({
    required String deviceId,
    required String platform,
    required String token,
  }) async {
    await _client.put('/communications/push-token', data: {
      'device_id': deviceId,
      'platform': platform,
      'token': token,
    });
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, item) => MapEntry('$key', item));
  throw const ApiException('The server returned an unexpected response.');
}

List<Map<String, dynamic>> _list(Object? value) {
  if (value is! List) {
    throw const ApiException('The server returned an unexpected response.');
  }
  return value.map(_map).toList(growable: false);
}
