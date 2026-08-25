import 'package:bid_book/core/api/api_exception.dart';
import 'package:bid_book/core/api/api_models.dart';
import 'package:bid_book/core/api/bidbook_api.dart';
import 'package:bid_book/features/auth/application/remote_auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final remoteMarketplaceProvider = AsyncNotifierProvider<RemoteMarketplaceController, RemoteMarketplaceState>(RemoteMarketplaceController.new);

final remoteBidHistoryProvider = FutureProvider.family<List<ApiBid>, String>((ref, requestId) async {
  final auth = ref.watch(remoteAuthControllerProvider).asData?.value;
  if (auth?.isAuthenticated != true) return const [];
  return ref.read(bidBookApiProvider).bids(requestId);
});

class RemoteMarketplaceState {
  const RemoteMarketplaceState({this.provider, this.services = const [], this.requests = const [], this.bookings = const []});
  final ApiProvider? provider;
  final List<ApiService> services;
  final List<ApiRequest> requests;
  final List<ApiBooking> bookings;

  RemoteMarketplaceState copyWith({ApiProvider? provider, List<ApiService>? services, List<ApiRequest>? requests, List<ApiBooking>? bookings}) => RemoteMarketplaceState(
        provider: provider ?? this.provider,
        services: services ?? this.services,
        requests: requests ?? this.requests,
        bookings: bookings ?? this.bookings,
      );
}

class RemoteMarketplaceController extends AsyncNotifier<RemoteMarketplaceState> {
  BidBookApi get _api => ref.read(bidBookApiProvider);

  @override
  Future<RemoteMarketplaceState> build() async {
    final user = ref.watch(remoteAuthControllerProvider).asData?.value.user;
    if (user == null) return const RemoteMarketplaceState();
    return _loadAll();
  }

  Future<RemoteMarketplaceState> _loadAll() async => RemoteMarketplaceState(
        provider: await _api.myProvider(),
        services: await _api.services(),
        requests: await _api.requests(),
        bookings: await _api.bookings(),
      );

  Future<void> refreshAll() async {
    try {
      state = AsyncData(await _loadAll());
    } catch (error, stack) {
      state = AsyncError<RemoteMarketplaceState>(error, stack);
    }
  }

  Future<ApiProvider> upsertProvider({required ApiProviderKind kind, required String displayName, required String serviceArea, String? bio}) async {
    final provider = await _api.upsertProvider(kind: kind, displayName: displayName, serviceArea: serviceArea, bio: bio);
    final current = state.asData?.value ?? const RemoteMarketplaceState();
    state = AsyncData(current.copyWith(provider: provider));
    return provider;
  }

  Future<ApiService> createService({required String title, required String category, required String description, required String area, required int pricePaise, required ApiPricingUnit pricingUnit}) async {
    final service = await _api.createService(title: title, category: category, description: description, area: area, pricePaise: pricePaise, pricingUnit: pricingUnit);
    final current = state.asData?.value ?? const RemoteMarketplaceState();
    state = AsyncData(current.copyWith(services: [service, ...current.services]));
    return service;
  }

  Future<ApiRequest> createRequest({required String title, required String category, required String description, required String area, required DateTime requestedFor}) async {
    final request = await _api.createRequest(title: title, category: category, description: description, area: area, requestedFor: requestedFor);
    final current = state.asData?.value ?? const RemoteMarketplaceState();
    state = AsyncData(current.copyWith(requests: [request, ...current.requests]));
    return request;
  }

  Future<ApiBooking> directBook({required String listingId, required DateTime scheduledFor, required String area}) async {
    final booking = await _api.directBook(listingId: listingId, scheduledFor: scheduledFor, area: area);
    final current = state.asData?.value ?? const RemoteMarketplaceState();
    state = AsyncData(current.copyWith(bookings: [booking, ...current.bookings]));
    return booking;
  }

  Future<ApiBid> submitBid({required String requestId, required int amountPaise, String? note}) async {
    final bid = await _api.submitBid(requestId: requestId, amountPaise: amountPaise, note: note);
    ref.invalidate(remoteBidHistoryProvider(requestId));
    return bid;
  }

  Future<ApiBooking> awardBid({required String requestId, required String bidId}) async {
    final booking = await _api.awardBid(requestId: requestId, bidId: bidId);
    ref.invalidate(remoteBidHistoryProvider(requestId));
    state = AsyncData(await _loadAll());
    return booking;
  }

  String friendlyError(Object error) => error is ApiException ? error.message : 'Something went wrong. Please try again.';
}
