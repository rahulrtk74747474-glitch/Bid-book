enum BookingSource { directListing, acceptedBid }

enum BookingStatus { confirmed, ongoing, completed, cancelled }

class Booking {
  const Booking({
    required this.id,
    required this.source,
    required this.customerUserId,
    required this.providerId,
    required this.providerName,
    required this.serviceTitle,
    required this.amountPaise,
    required this.scheduledFor,
    required this.createdAt,
    required this.status,
    this.requestId,
    this.bidEventId,
    this.listingId,
  });

  final String id;
  final BookingSource source;
  final String customerUserId;
  final String providerId;
  final String providerName;
  final String serviceTitle;
  final int amountPaise;
  final DateTime scheduledFor;
  final DateTime createdAt;
  final BookingStatus status;
  final String? requestId;
  final String? bidEventId;
  final String? listingId;

  double get amountRupees => amountPaise / 100;
}
