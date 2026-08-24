import 'package:bid_book/features/bidding/domain/bid_event.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

final bidHistoryProvider =
    NotifierProvider<BidHistoryController, List<BidEvent>>(
  BidHistoryController.new,
);

class BidHistoryController extends Notifier<List<BidEvent>> {
  static const _uuid = Uuid();

  @override
  List<BidEvent> build() => List.unmodifiable(_seed);

  void submitBid({
    required String requestId,
    required String providerId,
    required String providerName,
    required int amountPaise,
    required double rating,
    required int completedJobs,
    required bool identityVerified,
    String? note,
  }) {
    if (amountPaise <= 0) {
      throw ArgumentError.value(amountPaise, 'amountPaise', 'Must be positive');
    }

    final previous = state
        .where((event) =>
            event.requestId == requestId && event.providerId == providerId)
        .toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    final event = BidEvent(
      id: _uuid.v4(),
      requestId: requestId,
      providerId: providerId,
      providerName: providerName,
      amountPaise: amountPaise,
      submittedAt: DateTime.now().toUtc(),
      type: previous.isEmpty ? BidEventType.initialBid : BidEventType.revisedBid,
      previousBidEventId: previous.isEmpty ? null : previous.first.id,
      rating: rating,
      completedJobs: completedJobs,
      identityVerified: identityVerified,
      note: note,
    );

    // APPEND ONLY: a newer bid is an additional event. Never replace or
    // delete a provider's previous prices from the request ledger.
    state = List.unmodifiable([...state, event]);
  }

  static final List<BidEvent> _seed = [
    BidEvent(
      id: 'bid-001',
      requestId: 'req-ac-001',
      providerId: 'provider-coolcare',
      providerName: 'CoolCare Services',
      amountPaise: 34900,
      submittedAt: DateTime.utc(2026, 8, 24, 18, 5),
      type: BidEventType.initialBid,
      rating: 4.8,
      completedJobs: 1240,
      identityVerified: true,
      note: 'Includes indoor + outdoor unit cleaning.',
    ),
    BidEvent(
      id: 'bid-002',
      requestId: 'req-ac-001',
      providerId: 'provider-freshair',
      providerName: 'FreshAir AC Works',
      amountPaise: 33500,
      submittedAt: DateTime.utc(2026, 8, 24, 18, 17),
      type: BidEventType.initialBid,
      rating: 4.6,
      completedJobs: 625,
      identityVerified: true,
      note: '7-day workmanship warranty.',
    ),
    BidEvent(
      id: 'bid-003',
      requestId: 'req-ac-001',
      providerId: 'provider-coolcare',
      providerName: 'CoolCare Services',
      amountPaise: 32500,
      submittedAt: DateTime.utc(2026, 8, 24, 18, 29),
      type: BidEventType.revisedBid,
      previousBidEventId: 'bid-001',
      rating: 4.8,
      completedJobs: 1240,
      identityVerified: true,
      note: 'Revised group price for 40+ units.',
    ),
  ];
}
