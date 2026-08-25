import 'package:bid_book/core/api/api_exception.dart';
import 'package:bid_book/features/auth/application/remote_auth_controller.dart';
import 'package:bid_book/features/marketplace/application/remote_marketplace_controller.dart';
import 'package:bid_book/features/operations/data/operations_api.dart';
import 'package:bid_book/features/operations/domain/operations_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final remoteOperationsProvider = AsyncNotifierProvider<
    RemoteOperationsController,
    RemoteOperationsState>(RemoteOperationsController.new);

class RemoteOperationsState {
  const RemoteOperationsState({
    this.supportCases = const [],
    this.reports = const [],
    this.availability = const [],
    this.adminOverview,
  });

  final List<OpsSupportCase> supportCases;
  final List<OpsReport> reports;
  final List<OpsAvailability> availability;
  final AdminOverviewModel? adminOverview;

  bool get isAdmin => adminOverview != null;

  RemoteOperationsState copyWith({
    List<OpsSupportCase>? supportCases,
    List<OpsReport>? reports,
    List<OpsAvailability>? availability,
    AdminOverviewModel? adminOverview,
    bool clearAdmin = false,
  }) =>
      RemoteOperationsState(
        supportCases: supportCases ?? this.supportCases,
        reports: reports ?? this.reports,
        availability: availability ?? this.availability,
        adminOverview: clearAdmin ? null : adminOverview ?? this.adminOverview,
      );
}

class RemoteOperationsController extends AsyncNotifier<RemoteOperationsState> {
  OperationsApi get _api => ref.read(operationsApiProvider);

  @override
  Future<RemoteOperationsState> build() async {
    final auth = ref.watch(remoteAuthControllerProvider).asData?.value;
    if (auth?.isAuthenticated != true) return const RemoteOperationsState();
    final provider = ref.watch(remoteMarketplaceProvider).asData?.value.provider;
    return _load(providerAvailable: provider != null);
  }

  Future<RemoteOperationsState> _load({required bool providerAvailable}) async {
    final support = await _api.supportCases();
    final reports = await _api.reports();
    List<OpsAvailability> availability = const [];
    if (providerAvailable) {
      try {
        availability = await _api.availability();
      } on ApiException catch (error) {
        if (error.statusCode != 403) rethrow;
      }
    }
    AdminOverviewModel? adminOverview;
    try {
      adminOverview = await _api.adminOverview();
    } on ApiException catch (error) {
      if (error.statusCode != 403) rethrow;
    }
    return RemoteOperationsState(
      supportCases: support,
      reports: reports,
      availability: availability,
      adminOverview: adminOverview,
    );
  }

  Future<void> refreshAll() async {
    final provider = ref.read(remoteMarketplaceProvider).asData?.value.provider;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _load(providerAvailable: provider != null));
  }

  Future<void> createSupportCase({
    required String subject,
    required String category,
    required String description,
  }) async {
    final created = await _api.createSupportCase(
      subject: subject,
      category: category,
      description: description,
    );
    final current = state.asData?.value ?? const RemoteOperationsState();
    state = AsyncData(current.copyWith(
      supportCases: [created, ...current.supportCases],
    ));
  }

  Future<void> createReport({
    required String entityType,
    required String entityId,
    required String category,
    required String summary,
  }) async {
    final created = await _api.createReport(
      entityType: entityType,
      entityId: entityId,
      category: category,
      summary: summary,
    );
    final current = state.asData?.value ?? const RemoteOperationsState();
    state = AsyncData(current.copyWith(reports: [created, ...current.reports]));
  }

  Future<void> saveAvailability(List<OpsAvailability> slots) async {
    final saved = await _api.replaceAvailability(slots);
    final current = state.asData?.value ?? const RemoteOperationsState();
    state = AsyncData(current.copyWith(availability: saved));
  }

  Future<StartCodeResult> createStartCode(String bookingId) =>
      _api.createStartCode(bookingId);

  Future<String> startBookingWithCode({
    required String bookingId,
    required String code,
  }) =>
      _api.startBookingWithCode(bookingId: bookingId, code: code);

  Future<void> createWarrantyClaim({
    required String bookingId,
    required String issue,
  }) =>
      _api.createWarrantyClaim(bookingId: bookingId, issue: issue);

  Future<void> deleteAccount() => _api.deleteAccount();

  String friendlyError(Object error) => error is ApiException
      ? error.message
      : 'Something went wrong. Please try again.';
}
