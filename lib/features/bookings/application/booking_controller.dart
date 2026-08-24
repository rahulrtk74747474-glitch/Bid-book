import 'package:bid_book/features/bidding/domain/bid_event.dart';
import 'package:bid_book/features/bookings/domain/booking.dart';
import 'package:bid_book/features/requests/domain/service_request.dart';
import 'package:bid_book/features/services/domain/service_listing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

final bookingsProvider = NotifierProvider<BookingController, List<Booking>>(
  BookingController.new,
);

class BookingController extends Notifier<List<Booking>> {
  static const _uuid = Uuid();

  @override
  List<Booking> build() => const [];

  Booking createFromListing({
    required ServiceListing listing,
    required String customerUserId,
    required DateTime scheduledFor,
  }) {
    if (listing.ownerUserId == customerUserId) {
      throw StateError('You cannot book your own service listing.');
    }

    final booking = Booking(
      id: _uuid.v4(),
      source: BookingSource.directListing,
      customerUserId: customerUserId,
      providerId: listing.providerId,
      providerName: listing.providerName,
      serviceTitle: listing.title,
      amountPaise: listing.pricePaise,
      scheduledFor: scheduledFor,
      createdAt: DateTime.now().toUtc(),
      status: BookingStatus.confirmed,
      listingId: listing.id,
    );
    state = List.unmodifiable([booking, ...state]);
    return booking;
  }

  Booking createFromAcceptedBid({
    required ServiceRequest request,
    required BidEvent bid,
    required String customerUserId,
  }) {
    if (request.createdByUserId != customerUserId) {
      throw StateError('Only the request owner can accept a bid.');
    }
    if (bid.requestId != request.id) {
      throw StateError('Bid does not belong to this service request.');
    }

    final booking = Booking(
      id: _uuid.v4(),
      source: BookingSource.acceptedBid,
      customerUserId: customerUserId,
      providerId: bid.providerId,
      providerName: bid.providerName,
      serviceTitle: request.title,
      amountPaise: bid.amountPaise,
      scheduledFor: request.requestedFor,
      createdAt: DateTime.now().toUtc(),
      status: BookingStatus.confirmed,
      requestId: request.id,
      bidEventId: bid.id,
    );
    state = List.unmodifiable([booking, ...state]);
    return booking;
  }
}
