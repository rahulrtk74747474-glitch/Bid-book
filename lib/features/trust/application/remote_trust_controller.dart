import 'package:bid_book/core/api/api_exception.dart';
import 'package:bid_book/features/auth/application/remote_auth_controller.dart';
import 'package:bid_book/features/marketplace/application/remote_marketplace_controller.dart';
import 'package:bid_book/features/trust/data/trust_api.dart';
import 'package:bid_book/features/trust/domain/trust_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final remoteTrustProvider =
    AsyncNotifierProvider<RemoteTrustController, RemoteTrustState>(
  RemoteTrustController.new,
);

final bookingTrustProvider =
    FutureProvider.family<BookingTrustState, String>((ref, bookingId) async {
  final auth = ref.watch(remoteAuthControllerProvider).asData?.value;
  if (auth?.isAuthenticated != true) {
    throw const ApiException('Sign in to view booking trust details.');
  }
  return ref.read(trustApiProvider).bookingTrust(bookingId);
});

final providerReviewSummaryProvider =
    FutureProvider.family<ProviderReviewSummary, String>((ref, providerId) {
  return ref.read(trustApiProvider).providerReviewSummary(providerId);
});

class RemoteTrustState {
  const RemoteTrustState({
    required this.overview,
    this.payments = const [],
    this.payouts = const [],
    this.disputes = const [],
  });

  final TrustOverview overview;
  final List<TrustPayment> payments;
  final List<TrustPayout> payouts;
  final List<TrustDispute> disputes;
}

class RemoteTrustController extends AsyncNotifier<RemoteTrustState> {
  TrustApi get _api => ref.read(trustApiProvider);

  @override
  Future<RemoteTrustState> build() async {
    final auth = ref.watch(remoteAuthControllerProvider).asData?.value;
    if (auth?.isAuthenticated != true) {
      return RemoteTrustState(
        overview: TrustOverview(
          identityVerified: false,
          paymentsCount: 0,
          payoutsCount: 0,
          openDisputesCount: 0,
        ),
      );
    }
    return _loadAll();
  }

  Future<RemoteTrustState> _loadAll() async {
    final values = await Future.wait<Object>([
      _api.overview(),
      _api.payments(),
      _api.payouts(),
      _api.disputes(),
    ]);
    return RemoteTrustState(
      overview: values[0] as TrustOverview,
      payments: values[1] as List<TrustPayment>,
      payouts: values[2] as List<TrustPayout>,
      disputes: values[3] as List<TrustDispute>,
    );
  }

  Future<void> refreshAll() async {
    try {
      state = AsyncData(await _loadAll());
    } catch (error, stack) {
      state = AsyncError<RemoteTrustState>(error, stack);
    }
  }

  Future<TrustVerification> startVerification(
    TrustVerificationMethod method,
  ) async {
    final result = await _api.startVerification(method);
    await refreshAll();
    return result;
  }

  Future<void> simulateVerify(String verificationId) async {
    await _api.simulateVerify(verificationId);
    ref.invalidate(remoteAuthControllerProvider);
    await refreshAll();
  }

  Future<void> createPayment(String bookingId) async {
    await _api.createPayment(bookingId);
    ref.invalidate(bookingTrustProvider(bookingId));
    await refreshAll();
  }

  Future<void> simulateCapture(String bookingId, String paymentId) async {
    await _api.simulateCapture(paymentId);
    ref.invalidate(bookingTrustProvider(bookingId));
    await refreshAll();
  }

  Future<void> startBooking(String bookingId) async {
    await _api.startBooking(bookingId);
    ref.invalidate(bookingTrustProvider(bookingId));
    await ref.read(remoteMarketplaceProvider.notifier).refreshAll();
  }

  Future<void> completeBooking(String bookingId) async {
    await _api.completeBooking(bookingId);
    ref.invalidate(bookingTrustProvider(bookingId));
    await ref.read(remoteMarketplaceProvider.notifier).refreshAll();
    await refreshAll();
  }

  Future<void> createReview({
    required String bookingId,
    required int rating,
    String? comment,
  }) async {
    await _api.createReview(
      bookingId: bookingId,
      rating: rating,
      comment: comment,
    );
    ref.invalidate(bookingTrustProvider(bookingId));
  }

  Future<void> openDispute({
    required String bookingId,
    required String category,
    required String summary,
    required int requestedRefundPaise,
  }) async {
    await _api.openDispute(
      bookingId: bookingId,
      category: category,
      summary: summary,
      requestedRefundPaise: requestedRefundPaise,
    );
    ref.invalidate(bookingTrustProvider(bookingId));
    await refreshAll();
  }

  String friendlyError(Object error) => error is ApiException
      ? error.message
      : 'Something went wrong. Please try again.';
}
