import 'package:bid_book/core/api/api_client.dart';
import 'package:bid_book/core/api/api_exception.dart';
import 'package:bid_book/features/production/domain/production_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final productionApiProvider = Provider<ProductionApi>(
  (ref) => ProductionApi(ref.read(apiClientProvider)),
);

class ProductionApi {
  const ProductionApi(this._client);
  final ApiClient _client;

  Future<String> adminStepUp(String code) async {
    final data = _map(await _client.post(
      '/production/admin/step-up',
      data: {'code': code},
    ));
    final token = data['token'] as String?;
    if (token == null || token.isEmpty) {
      throw const ApiException('Admin verification did not return a token.');
    }
    _client.setAdminStepupToken(token);
    return token;
  }

  Future<ProductionProviderProfile> providerProfile() async =>
      ProductionProviderProfile.fromJson(
        _map(await _client.get('/production/provider/profile')),
      );

  Future<ProductionProviderProfile> updateProviderProfile({
    required int yearsExperience,
    required List<String> languages,
    required List<String> skills,
    String? gstin,
    required int serviceRadiusKm,
    double? latitude,
    double? longitude,
    String? payoutAccountReference,
    String? payoutMethodLabel,
    String? portfolioHeadline,
  }) async =>
      ProductionProviderProfile.fromJson(
        _map(await _client.put('/production/provider/profile', data: {
          'years_experience': yearsExperience,
          'languages': languages,
          'skills': skills,
          'gstin': _nullable(gstin),
          'service_radius_km': serviceRadiusKm,
          'latitude': latitude,
          'longitude': longitude,
          'payout_account_reference': _nullable(payoutAccountReference),
          'payout_method_label': _nullable(payoutMethodLabel),
          'portfolio_headline': _nullable(portfolioHeadline),
        })),
      );

  Future<List<NearbyService>> nearbyServices({
    required double latitude,
    required double longitude,
    int radiusKm = 25,
    String? category,
    bool verifiedOnly = false,
  }) async {
    final data = await _client.get('/production/discovery/nearby', query: {
      'latitude': latitude,
      'longitude': longitude,
      'radius_km': radiusKm,
      if (category?.trim().isNotEmpty == true) 'category': category!.trim(),
      'verified_only': verifiedOnly,
      'limit': 100,
    });
    return _list(data).map(NearbyService.fromJson).toList(growable: false);
  }

  Future<List<ProviderStaffMember>> staff() async {
    final data = await _client.get('/production/provider/staff');
    return _list(data).map(ProviderStaffMember.fromJson).toList(growable: false);
  }

  Future<ProviderStaffMember> addStaff({
    required String phone,
    required String role,
  }) async =>
      ProviderStaffMember.fromJson(
        _map(await _client.post('/production/provider/staff', data: {
          'phone': phone,
          'role': role,
        })),
      );

  Future<void> removeStaff(String userId) async {
    await _client.delete('/production/provider/staff/$userId');
  }

  Future<Map<String, dynamic>> assignBooking({
    required String bookingId,
    required String staffUserId,
  }) async =>
      _map(await _client.post('/production/bookings/$bookingId/assignment', data: {
        'staff_user_id': staffUserId,
      }));

  Future<Map<String, dynamic>> exportAccount() async =>
      _map(await _client.get('/production/account/export'));

  Future<String> launchIdentityVerification(String verificationId) async {
    final data = _map(await _client.post(
      '/production/identity/verifications/$verificationId/launch',
    ));
    final url = data['launch_url'] as String?;
    if (url == null || !url.startsWith('https://')) {
      throw const ApiException('Identity provider returned an invalid URL.');
    }
    return url;
  }

  Future<MediaUploadIntent> createMediaIntent({
    required String entityType,
    required String entityId,
    required String contentType,
    required int sizeBytes,
  }) async =>
      MediaUploadIntent.fromJson(
        _map(await _client.post('/ops/media/intents', data: {
          'entity_type': entityType,
          'entity_id': entityId,
          'content_type': contentType,
          'size_bytes': sizeBytes,
        })),
      );

  Future<Map<String, dynamic>> completeMedia(String mediaId) async =>
      _map(await _client.post('/production/media/$mediaId/complete'));
}

String? _nullable(String? value) {
  final text = value?.trim();
  return text == null || text.isEmpty ? null : text;
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
