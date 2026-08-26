import 'package:bid_book/core/api/api_client.dart';
import 'package:bid_book/core/api/api_exception.dart';
import 'package:bid_book/core/api/api_models.dart';
import 'package:bid_book/core/api/session_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final bidBookApiProvider = Provider<BidBookApi>((ref) => BidBookApi(
      ref.read(apiClientProvider),
      ref.read(sessionStoreProvider),
    ));

class BidBookApi {
  const BidBookApi(this._client, this._sessionStore);

  final ApiClient _client;
  final SessionStore _sessionStore;

  Future<void> _saveAuth(AuthResult result) => _sessionStore.saveTokens(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
      );

  Future<OtpChallengeResult> requestOtp(String phone) async {
    final data = await _client.post('/auth/otp/request', data: {'phone': phone}, authenticated: false);
    return OtpChallengeResult.fromJson(_map(data));
  }

  Future<AuthResult> verifyOtp({required String challengeId, required String otp}) async {
    final deviceId = await _sessionStore.deviceId();
    final result = AuthResult.fromJson(_map(await _client.post('/auth/otp/verify', data: {
      'challenge_id': challengeId,
      'otp': otp,
      'device_id': deviceId,
    }, authenticated: false)));
    await _saveAuth(result);
    return result;
  }

  Future<AuthResult> registerEmail({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final deviceId = await _sessionStore.deviceId();
    final result = AuthResult.fromJson(_map(await _client.post('/auth/email/register', data: {
      'display_name': displayName,
      'email': email,
      'password': password,
      'device_id': deviceId,
    }, authenticated: false)));
    await _saveAuth(result);
    return result;
  }

  Future<AuthResult> loginEmail({required String email, required String password}) async {
    final deviceId = await _sessionStore.deviceId();
    final result = AuthResult.fromJson(_map(await _client.post('/auth/email/login', data: {
      'email': email,
      'password': password,
      'device_id': deviceId,
    }, authenticated: false)));
    await _saveAuth(result);
    return result;
  }

  Future<AuthResult> loginGoogle(String idToken) async {
    final deviceId = await _sessionStore.deviceId();
    final result = AuthResult.fromJson(_map(await _client.post('/auth/google', data: {
      'id_token': idToken,
      'device_id': deviceId,
    }, authenticated: false)));
    await _saveAuth(result);
    return result;
  }

  Future<ApiUser> me() async => ApiUser.fromJson(_map(await _client.get('/auth/me')));

  Future<void> logout() async {
    await _sessionStore.ensureLoaded();
    final refresh = _sessionStore.refreshToken;
    if (refresh != null) {
      try {
        await _client.post('/auth/logout', data: {'refresh_token': refresh});
      } catch (_) {}
    }
    await _sessionStore.clearTokens();
  }

  Future<bool> hasSavedSession() async {
    await _sessionStore.ensureLoaded();
    return _sessionStore.hasSession;
  }

  Future<ApiProvider?> myProvider() async {
    final data = await _client.get('/providers/me');
    if (data == null) return null;
    return ApiProvider.fromJson(_map(data));
  }

  Future<ApiProvider> upsertProvider({
    required ApiProviderKind kind,
    required String displayName,
    required String serviceArea,
    String? bio,
  }) async {
    final data = await _client.put('/providers/me', data: {
      'kind': kind.wireName,
      'display_name': displayName,
      'service_area': serviceArea,
      'bio': bio,
    });
    return ApiProvider.fromJson(_map(data));
  }

  Future<List<ApiService>> services({String? category, String? area}) async {
    final data = await _client.get('/services', query: {
      if (category?.trim().isNotEmpty == true) 'category': category!.trim(),
      if (area?.trim().isNotEmpty == true) 'area': area!.trim(),
      'limit': 100,
    });
    return _list(data).map(ApiService.fromJson).toList(growable: false);
  }

  Future<ApiService> createService({
    required String title,
    required String category,
    required String description,
    required String area,
    required int pricePaise,
    required ApiPricingUnit pricingUnit,
  }) async {
    final data = await _client.post('/services', data: {
      'title': title,
      'category': category,
      'description': description,
      'area': area,
      'price_paise': pricePaise,
      'pricing_unit': pricingUnit.wireName,
    });
    return ApiService.fromJson(_map(data));
  }

  Future<ApiBooking> directBook({required String listingId, required DateTime scheduledFor, required String area}) async {
    final data = await _client.post('/services/$listingId/book', data: {
      'scheduled_for': scheduledFor.toUtc().toIso8601String(),
      'area': area,
    });
    return ApiBooking.fromJson(_map(data));
  }

  Future<List<ApiRequest>> requests() async {
    final data = await _client.get('/requests', query: {'limit': 100});
    return _list(data).map(ApiRequest.fromJson).toList(growable: false);
  }

  Future<ApiRequest> createRequest({
    required String title,
    required String category,
    required String description,
    required String area,
    required DateTime requestedFor,
  }) async {
    final data = await _client.post('/requests', data: {
      'title': title,
      'category': category,
      'description': description,
      'area': area,
      'requested_for': requestedFor.toUtc().toIso8601String(),
    });
    return ApiRequest.fromJson(_map(data));
  }

  Future<List<ApiBid>> bids(String requestId) async {
    final data = await _client.get('/requests/$requestId/bids');
    return _list(data).map(ApiBid.fromJson).toList(growable: false);
  }

  Future<ApiBid> submitBid({required String requestId, required int amountPaise, String? note}) async {
    final data = await _client.post('/requests/$requestId/bids', data: {
      'amount_paise': amountPaise,
      'note': note?.trim().isEmpty == true ? null : note?.trim(),
    });
    return ApiBid.fromJson(_map(data));
  }

  Future<ApiBooking> awardBid({required String requestId, required String bidId}) async {
    final data = await _client.post('/requests/$requestId/award/$bidId');
    return ApiBooking.fromJson(_map(data));
  }

  Future<List<ApiBooking>> bookings() async {
    final data = await _client.get('/bookings');
    return _list(data).map(ApiBooking.fromJson).toList(growable: false);
  }

  Future<List<ApiGroup>> groups() async {
    final data = await _client.get('/groups');
    return _list(data).map(ApiGroup.fromJson).toList(growable: false);
  }

  Future<ApiGroup> createGroup({required String name, required String area}) async {
    final data = await _client.post('/groups', data: {'name': name, 'area': area});
    return ApiGroup.fromJson(_map(data));
  }

  Future<void> joinGroup(String inviteCode) async {
    await _client.post('/groups/join', data: {'invite_code': inviteCode});
  }

  Future<List<ApiProposal>> proposals(String groupId) async {
    final data = await _client.get('/groups/$groupId/proposals');
    return _list(data).map(ApiProposal.fromJson).toList(growable: false);
  }

  Future<ApiProposal> createProposal({
    required String groupId,
    required String title,
    required String category,
    required String description,
    required DateTime preferredFor,
  }) async {
    final data = await _client.post('/groups/$groupId/proposals', data: {
      'title': title,
      'category': category,
      'description': description,
      'preferred_for': preferredFor.toUtc().toIso8601String(),
    });
    return ApiProposal.fromJson(_map(data));
  }

  Future<void> vote({
    required String groupId,
    required String proposalId,
    required ApiVoteChoice choice,
    required int quantity,
  }) async {
    await _client.put('/groups/$groupId/proposals/$proposalId/vote', data: {
      'choice': choice.name,
      'quantity': quantity,
    });
  }

  Future<ApiProposalSummary> proposalSummary({required String groupId, required String proposalId}) async =>
      ApiProposalSummary.fromJson(_map(await _client.get('/groups/$groupId/proposals/$proposalId/summary')));

  Future<ApiRequest> publishProposal({required String groupId, required String proposalId}) async =>
      ApiRequest.fromJson(_map(await _client.post('/groups/$groupId/proposals/$proposalId/publish')));
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, item) => MapEntry('$key', item));
  throw const ApiException('The server returned an unexpected response.');
}

List<Map<String, dynamic>> _list(Object? value) {
  if (value is! List) throw const ApiException('The server returned an unexpected response.');
  return value.map(_map).toList(growable: false);
}
