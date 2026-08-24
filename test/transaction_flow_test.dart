import 'package:bid_book/features/bookings/application/booking_controller.dart';
import 'package:bid_book/features/marketplace/application/marketplace_actions.dart';
import 'package:bid_book/features/requests/application/request_controller.dart';
import 'package:bid_book/features/requests/domain/service_request.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepting latest bid snapshots exact bid id and amount into booking', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final booking = container
        .read(marketplaceActionsProvider.notifier)
        .acceptBid(
          requestId: 'req-ac-001',
          bidEventId: 'bid-003',
          customerUserId: 'user-demo',
        );

    expect(booking.bidEventId, 'bid-003');
    expect(booking.amountPaise, 32500);

    final request = container
        .read(serviceRequestsProvider)
        .firstWhere((item) => item.id == 'req-ac-001');
    expect(request.status, ServiceRequestStatus.booked);
    expect(request.acceptedBidEventId, 'bid-003');
    expect(request.bookingId, booking.id);
    expect(container.read(bookingsProvider).single.id, booking.id);
  });

  test('historical provider bid cannot be accepted after a revision', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      () => container.read(marketplaceActionsProvider.notifier).acceptBid(
            requestId: 'req-ac-001',
            bidEventId: 'bid-001',
            customerUserId: 'user-demo',
          ),
      throwsStateError,
    );
  });

  test('only request owner can accept a bid', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      () => container.read(marketplaceActionsProvider.notifier).acceptBid(
            requestId: 'req-ac-001',
            bidEventId: 'bid-003',
            customerUserId: 'someone-else',
          ),
      throwsStateError,
    );
  });
}
