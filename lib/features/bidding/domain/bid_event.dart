enum BidEventType { initialBid, revisedBid }

/// One immutable price submission in a request's transparent bid ledger.
///
/// A provider revision MUST create a new [BidEvent]. Existing events are never
/// edited or deleted from the business ledger. Server-side persistence will
/// enforce the same append-only rule and add audit timestamps.
class BidEvent {
  const BidEvent({
    required this.id,
    required this.requestId,
    required this.providerId,
    required this.providerName,
    required this.amountPaise,
    required this.submittedAt,
    required this.type,
    required this.rating,
    required this.completedJobs,
    required this.identityVerified,
    this.note,
    this.previousBidEventId,
  });

  final String id;
  final String requestId;
  final String providerId;
  final String providerName;
  final int amountPaise;
  final DateTime submittedAt;
  final BidEventType type;
  final double rating;
  final int completedJobs;
  final bool identityVerified;
  final String? note;
  final String? previousBidEventId;

  double get amountRupees => amountPaise / 100;
}
