import 'package:bid_book/features/bidding/application/bid_history_controller.dart';
import 'package:bid_book/features/bidding/domain/bid_event.dart';
import 'package:bid_book/features/bookings/application/booking_controller.dart';
import 'package:bid_book/features/bookings/domain/booking.dart';
import 'package:bid_book/features/requests/application/request_controller.dart';
import 'package:bid_book/features/requests/domain/service_request.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final marketplaceActionsProvider =
    NotifierProvider<MarketplaceActions, int>(MarketplaceActions.new);

class MarketplaceActions extends Notifier<int> {
  @override
  int build() => 0;

  Booking acceptBid({
    required String requestId,
    required String bidEventId,
    required String customerUserId,
  }) {
    ServiceRequest? request;
    for (final item in ref.read(serviceRequestsProvider)) {
      if (item.id == requestId) {
        request = item;
        break;
      }
    }
    if (request == null) {
      throw StateError('Service request not found.');
    }
    final currentRequest = request;
    if (currentRequest.createdByUserId != customerUserId) {
      throw StateError('Only the request owner can accept a bid.');
    }
    if (currentRequest.status != ServiceRequestStatus.bidding) {
      throw StateError('Bidding is no longer open for this request.');
    }

    final history = ref.read(bidHistoryProvider);
    BidEvent? bid;
    for (final item in history) {
      if (item.id == bidEventId) {
        bid = item;
        break;
      }
    }
    if (bid == null || bid.requestId != requestId) {
      throw StateError('Bid not found for this request.');
    }
    final currentBid = bid;

    final hasNewerProviderBid = history.any(
      (item) =>
          item.requestId == requestId &&
          item.providerId == currentBid.providerId &&
          item.submittedAt.isAfter(currentBid.submittedAt),
    );
    if (hasNewerProviderBid) {
      throw StateError(
        'This is a historical bid. Only the provider’s latest offer can be accepted.',
      );
    }

    final booking = ref.read(bookingsProvider.notifier).createFromAcceptedBid(
          request: currentRequest,
          bid: currentBid,
          customerUserId: customerUserId,
        );
    ref.read(serviceRequestsProvider.notifier).markBooked(
          requestId: currentRequest.id,
          bidEventId: currentBid.id,
          bookingId: booking.id,
        );
    state++;
    return booking;
  }
}
