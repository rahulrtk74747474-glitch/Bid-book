import 'package:bid_book/features/bidding/application/bid_history_controller.dart';
import 'package:bid_book/features/bidding/domain/bid_event.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rebidding appends history instead of overwriting old bids', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final before = container.read(bidHistoryProvider);
    final providerBefore = before
        .where((event) =>
            event.requestId == 'req-ac-001' &&
            event.providerId == 'provider-coolcare')
        .length;

    container.read(bidHistoryProvider.notifier).submitBid(
          requestId: 'req-ac-001',
          providerId: 'provider-coolcare',
          providerName: 'CoolCare Services',
          amountPaise: 31000,
          rating: 4.8,
          completedJobs: 1240,
          identityVerified: true,
        );

    final after = container.read(bidHistoryProvider);
    final providerEvents = after
        .where((event) =>
            event.requestId == 'req-ac-001' &&
            event.providerId == 'provider-coolcare')
        .toList();

    expect(providerEvents.length, providerBefore + 1);
    expect(providerEvents.last.type, BidEventType.revisedBid);
    expect(providerEvents.last.previousBidEventId, isNotNull);
    expect(after.length, before.length + 1);
    expect(
      after.any((event) => event.id == 'bid-001' && event.amountPaise == 34900),
      isTrue,
    );
    expect(
      after.any((event) => event.id == 'bid-003' && event.amountPaise == 32500),
      isTrue,
    );
  });

  test('invalid bid amount is rejected', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      () => container.read(bidHistoryProvider.notifier).submitBid(
            requestId: 'req-ac-001',
            providerId: 'provider-test',
            providerName: 'Test Provider',
            amountPaise: 0,
            rating: 5,
            completedJobs: 1,
            identityVerified: true,
          ),
      throwsArgumentError,
    );
  });
}
