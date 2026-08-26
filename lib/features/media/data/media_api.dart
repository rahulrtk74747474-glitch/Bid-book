import 'dart:typed_data';

import 'package:bid_book/core/api/api_client.dart';
import 'package:bid_book/core/api/api_config.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

final mediaApiProvider = Provider<MediaApi>((ref) => MediaApi(ref.read(apiClientProvider)));

final mediaGalleryProvider = FutureProvider.family<List<String>, String>((ref, key) async {
  final split = key.indexOf('|');
  if (split < 1) return const [];
  return ref.read(mediaApiProvider).gallery(
        entityType: key.substring(0, split),
        entityId: key.substring(split + 1),
      );
});

class MediaApi {
  const MediaApi(this._client);
  final ApiClient _client;

  Future<List<String>> gallery({required String entityType, required String entityId}) async {
    final data = await _client.get('/ops/media/gallery/$entityType/$entityId');
    if (data is! List) return const [];
    return data.map((item) => ApiConfig.absoluteUrl(item.toString())).toList(growable: false);
  }

  Future<void> uploadImages({
    required String entityType,
    required String entityId,
    required List<XFile> files,
  }) async {
    for (final file in files) {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) continue;
      if (bytes.length > 15 * 1024 * 1024) {
        throw StateError('${file.name} is larger than 15 MB.');
      }
      final contentType = _contentType(file.name);
      final intent = _map(await _client.post('/ops/media/intents', data: {
        'entity_type': entityType,
        'entity_id': entityId,
        'content_type': contentType,
        'size_bytes': bytes.length,
      }));
      final id = intent['id'].toString();
      final uploadUrl = intent['upload_url']?.toString() ?? '';
      if (uploadUrl.startsWith('development://')) {
        await _client.put(
          '/ops/media/$id/content',
          data: Uint8List.fromList(bytes),
          headers: {'Content-Type': contentType},
        );
      } else {
        if (!uploadUrl.startsWith('https://')) {
          throw StateError('Secure photo upload is not configured.');
        }
        final dio = Dio();
        try {
          await dio.put<void>(
            uploadUrl,
            data: Uint8List.fromList(bytes),
            options: Options(
              contentType: contentType,
              headers: {'Content-Length': bytes.length},
            ),
          );
        } finally {
          dio.close(force: true);
        }
        await _client.post('/ops/media/$id/complete');
      }
    }
    refetchHint(entityType, entityId);
  }

  void refetchHint(String entityType, String entityId) {}

  String _contentType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, item) => MapEntry('$key', item));
  throw const FormatException('Expected a JSON object');
}
