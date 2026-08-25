import 'package:bid_book/core/api/api_client.dart';
import 'package:bid_book/core/api/api_exception.dart';
import 'package:bid_book/features/operations/domain/operations_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final operationsApiProvider = Provider<OperationsApi>(
  (ref) => OperationsApi(ref.read(apiClientProvider)),
);

class OperationsApi {
  const OperationsApi(this._client);
  final ApiClient _client;

  Future<List<OpsSupportCase>> supportCases() async {
    final data = await _client.get('/ops/support/cases');
    return _list(data).map(OpsSupportCase.fromJson).toList(growable: false);
  }

  Future<OpsSupportCase> createSupportCase({
    required String subject,
    required String category,
    required String description,
    String priority = 'normal',
  }) async =>
      OpsSupportCase.fromJson(_map(await _client.post('/ops/support/cases', data: {
            'subject': subject,
            'category': category,
            'description': description,
            'priority': priority,
          })));

  Future<List<OpsReport>> reports() async {
    final data = await _client.get('/ops/reports');
    return _list(data).map(OpsReport.fromJson).toList(growable: false);
  }

  Future<OpsReport> createReport({
    required String entityType,
    required String entityId,
    required String category,
    required String summary,
  }) async =>
      OpsReport.fromJson(_map(await _client.post('/ops/reports', data: {
            'entity_type': entityType,
            'entity_id': entityId,
            'category': category,
            'summary': summary,
          })));

  Future<List<OpsAvailability>> availability() async {
    final data = await _client.get('/ops/provider/availability');
    return _list(data).map(OpsAvailability.fromJson).toList(growable: false);
  }

  Future<List<OpsAvailability>> replaceAvailability(
    List<OpsAvailability> slots,
  ) async {
    final data = await _client.put('/ops/provider/availability', data: {
      'slots': slots.map((slot) => slot.toJson()).toList(growable: false),
    });
    return _list(data).map(OpsAvailability.fromJson).toList(growable: false);
  }

  Future<List<DiscoveryService>> discoverServices({
    String? query,
    String? category,
    String? area,
    bool verifiedOnly = false,
    int? weekday,
    String sort = 'newest',
  }) async {
    final data = await _client.get('/ops/discovery/services', query: {
      if (query?.trim().isNotEmpty == true) 'q': query!.trim(),
      if (category?.trim().isNotEmpty == true) 'category': category!.trim(),
      if (area?.trim().isNotEmpty == true) 'area': area!.trim(),
      'verified_only': verifiedOnly,
      if (weekday != null) 'weekday': weekday,
      'sort': sort,
      'limit': 100,
    });
    return _list(data).map(DiscoveryService.fromJson).toList(growable: false);
  }

  Future<StartCodeResult> createStartCode(String bookingId) async =>
      StartCodeResult.fromJson(
        _map(await _client.post('/ops/bookings/$bookingId/start-code')),
      );

  Future<String> startBookingWithCode({
    required String bookingId,
    required String code,
  }) async {
    final data = _map(await _client.post(
      '/ops/bookings/$bookingId/start',
      data: {'code': code},
    ));
    return data['status'] as String? ?? 'in_progress';
  }

  Future<void> createWarrantyClaim({
    required String bookingId,
    required String issue,
  }) async {
    await _client.post(
      '/ops/bookings/$bookingId/warranty-claims',
      data: {'issue': issue},
    );
  }

  Future<void> blockUser(String userId) async {
    await _client.put('/ops/blocks/$userId');
  }

  Future<void> unblockUser(String userId) async {
    await _client.delete('/ops/blocks/$userId');
  }

  Future<void> deleteAccount() async {
    await _client.post('/ops/account/delete');
  }

  Future<AdminOverviewModel> adminOverview() async =>
      AdminOverviewModel.fromJson(_map(await _client.get('/admin/overview')));

  Future<List<Map<String, dynamic>>> adminUsers() async =>
      _list(await _client.get('/admin/users'));

  Future<Map<String, dynamic>> suspendUser(String userId, String reason) async =>
      _map(await _client.post('/admin/users/$userId/suspend', data: {'reason': reason}));

  Future<Map<String, dynamic>> restoreUser(String userId) async =>
      _map(await _client.post('/admin/users/$userId/restore'));

  Future<List<Map<String, dynamic>>> adminVerifications() async =>
      _list(await _client.get('/admin/verifications'));

  Future<void> decideVerification(String id, String status, {String? reason}) async {
    await _client.post('/admin/verifications/$id/decision', data: {
      'status': status,
      'reason': reason,
    });
  }

  Future<List<Map<String, dynamic>>> adminDisputes() async =>
      _list(await _client.get('/admin/disputes'));

  Future<void> resolveDispute({
    required String id,
    required String resolution,
    int refundPaise = 0,
  }) async {
    await _client.post('/admin/disputes/$id/resolve', data: {
      'status': 'resolved',
      'resolution': resolution,
      'refund_paise': refundPaise,
    });
  }

  Future<List<Map<String, dynamic>>> adminPayouts() async =>
      _list(await _client.get('/admin/payouts'));

  Future<void> processPayout(String id, String status) async {
    await _client.post('/admin/payouts/$id/process', data: {'status': status});
  }

  Future<List<Map<String, dynamic>>> adminRisks() async =>
      _list(await _client.get('/admin/risks'));

  Future<void> decideRisk(String id, String status, {String? detail}) async {
    await _client.post('/admin/risks/$id/decision', data: {
      'status': status,
      'detail': detail,
    });
  }

  Future<List<Map<String, dynamic>>> adminReports() async =>
      _list(await _client.get('/admin/reports'));

  Future<void> decideReport(String id, String status, String resolution) async {
    await _client.post('/admin/reports/$id/decision', data: {
      'status': status,
      'resolution': resolution,
    });
  }

  Future<List<Map<String, dynamic>>> adminSupportCases() async =>
      _list(await _client.get('/admin/support/cases'));

  Future<void> decideSupportCase(String id, String status) async {
    await _client.post('/admin/support/cases/$id/decision', data: {
      'status': status,
      'assign_to_me': true,
    });
  }

  Future<List<Map<String, dynamic>>> adminWarrantyClaims() async =>
      _list(await _client.get('/admin/warranty-claims'));

  Future<void> decideWarranty(String id, String status, String resolution) async {
    await _client.post('/admin/warranty-claims/$id/decision', data: {
      'status': status,
      'resolution': resolution,
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
