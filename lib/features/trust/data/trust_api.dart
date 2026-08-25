import 'package:bid_book/core/api/api_client.dart';
import 'package:bid_book/core/api/api_exception.dart';
import 'package:bid_book/features/trust/domain/trust_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final trustApiProvider = Provider<TrustApi>(
  (ref) => TrustApi(ref.read(apiClientProvider)),
);

class TrustApi {
  const TrustApi(this._client);
  final ApiClient _client;

  Future<TrustOverview> overview() async =>
      TrustOverview.fromJson(_map(await _client.get('/trust/overview')));

  Future<List<TrustVerification>> verifications() async {
    final data = await _client.get('/trust/identity/verifications');
    return _list(data).map(TrustVerification.fromJson).toList(growable: false);
  }

  Future<TrustVerification> startVerification(
    TrustVerificationMethod method,
  ) async =>
      TrustVerification.fromJson(_map(await _client.post(
        '/trust/identity/verifications',
        data: {'method': method.wireName},
      )));

  Future<TrustVerification> simulateVerify(String verificationId) async =>
      TrustVerification.fromJson(_map(await _client.post(
        '/trust/identity/verifications/$verificationId/simulate-verify',
      )));

  Future<BookingTrustState> bookingTrust(String bookingId) async =>
      BookingTrustState.fromJson(
        _map(await _client.get('/trust/bookings/$bookingId')),
      );

  Future<TrustPayment> createPayment(String bookingId) async =>
      TrustPayment.fromJson(_map(await _client.post(
        '/trust/bookings/$bookingId/payment',
      )));

  Future<TrustPayment> simulateCapture(String paymentId) async =>
      TrustPayment.fromJson(_map(await _client.post(
        '/trust/payments/$paymentId/simulate-capture',
      )));

  Future<String> startBooking({
    required String bookingId,
    required String code,
  }) async {
    final data = _map(await _client.post(
      '/ops/bookings/$bookingId/start',
      data: {'code': code},
    ));
    return data['status'] as String? ?? 'in_progress';
  }

  Future<String> completeBooking(String bookingId) async {
    final data = _map(await _client.post('/trust/bookings/$bookingId/complete'));
    return data['status'] as String? ?? 'completed';
  }

  Future<List<TrustPayment>> payments() async {
    final data = await _client.get('/trust/payments');
    return _list(data).map(TrustPayment.fromJson).toList(growable: false);
  }

  Future<List<TrustPayout>> payouts() async {
    final data = await _client.get('/trust/payouts');
    return _list(data).map(TrustPayout.fromJson).toList(growable: false);
  }

  Future<List<TrustDispute>> disputes() async {
    final data = await _client.get('/trust/disputes');
    return _list(data).map(TrustDispute.fromJson).toList(growable: false);
  }

  Future<void> createReview({
    required String bookingId,
    required int rating,
    String? comment,
  }) async {
    await _client.post('/trust/bookings/$bookingId/reviews', data: {
      'rating': rating,
      'comment': comment?.trim().isEmpty == true ? null : comment?.trim(),
    });
  }

  Future<TrustDispute> openDispute({
    required String bookingId,
    required String category,
    required String summary,
    required int requestedRefundPaise,
  }) async =>
      TrustDispute.fromJson(_map(await _client.post(
        '/trust/bookings/$bookingId/disputes',
        data: {
          'category': category,
          'summary': summary,
          'requested_refund_paise': requestedRefundPaise,
        },
      )));

  Future<ProviderReviewSummary> providerReviewSummary(String providerId) async =>
      ProviderReviewSummary.fromJson(_map(await _client.get(
        '/trust/providers/$providerId/review-summary',
      )));
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
