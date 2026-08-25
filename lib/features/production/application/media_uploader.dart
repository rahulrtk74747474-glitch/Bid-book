import 'dart:typed_data';

import 'package:bid_book/core/api/api_exception.dart';
import 'package:bid_book/features/production/data/production_api.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

class PickedBidBookFile {
  const PickedBidBookFile({
    required this.name,
    required this.bytes,
    required this.contentType,
  });

  final String name;
  final Uint8List bytes;
  final String contentType;
}

class MediaUploader {
  MediaUploader(this._api);

  final ProductionApi _api;
  final Dio _uploadDio = Dio();
  final ImagePicker _imagePicker = ImagePicker();

  Future<PickedBidBookFile?> pickPhoto({ImageSource source = ImageSource.gallery}) async {
    final file = await _imagePicker.pickImage(
      source: source,
      imageQuality: 88,
      maxWidth: 2200,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final mime = file.mimeType ?? _mimeFromName(file.name);
    return PickedBidBookFile(name: file.name, bytes: bytes, contentType: mime);
  }

  Future<PickedBidBookFile?> pickEvidenceDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) return null;
    final bytes = file.bytes;
    if (bytes == null) {
      throw const ApiException('Could not read the selected file.');
    }
    return PickedBidBookFile(
      name: file.name,
      bytes: bytes,
      contentType: _mimeFromName(file.name),
    );
  }

  Future<Map<String, dynamic>> upload({
    required String entityType,
    required String entityId,
    required PickedBidBookFile file,
  }) async {
    if (file.bytes.isEmpty) {
      throw const ApiException('The selected file is empty.');
    }
    if (file.bytes.length > 10 * 1024 * 1024) {
      throw const ApiException('Files must be 10 MB or smaller.');
    }

    final intent = await _api.createMediaIntent(
      entityType: entityType,
      entityId: entityId,
      contentType: file.contentType,
      sizeBytes: file.bytes.length,
    );
    if (!intent.uploadUrl.startsWith('development://')) {
      try {
        await _uploadDio.put<void>(
          intent.uploadUrl,
          data: Stream<List<int>>.value(file.bytes),
          options: Options(
            contentType: file.contentType,
            headers: {'Content-Length': file.bytes.length},
            responseType: ResponseType.plain,
            sendTimeout: const Duration(minutes: 2),
            receiveTimeout: const Duration(seconds: 30),
          ),
        );
      } on DioException catch (error) {
        throw ApiException(
          'The file could not be uploaded. Please try again.',
          statusCode: error.response?.statusCode,
        );
      }
    }
    return _api.completeMedia(intent.id);
  }

  void dispose() => _uploadDio.close(force: true);
}

String _mimeFromName(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.pdf')) return 'application/pdf';
  return 'image/jpeg';
}
