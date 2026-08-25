import 'package:dio/dio.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  factory ApiException.fromDio(DioException error) {
    final response = error.response;
    final data = response?.data;
    var message = 'Unable to reach Bid&Book. Check your connection and try again.';
    String? code;

    if (data is Map) {
      final detail = data['detail'];
      if (detail is String && detail.trim().isNotEmpty) message = detail;
      final apiCode = data['code'];
      if (apiCode is String) code = apiCode;
    } else if (data is String && data.trim().isNotEmpty) {
      message = data;
    } else if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      message = 'The server took too long to respond. Please try again.';
    }

    return ApiException(message, statusCode: response?.statusCode, code: code);
  }

  @override
  String toString() => message;
}
