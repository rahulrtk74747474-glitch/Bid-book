import 'package:bid_book/features/bookings/application/booking_controller.dart';
import 'package:bid_book/features/bookings/domain/booking.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class BookingDetailScreen extends ConsumerWidget {
  const BookingDetailScreen({required this.bookingId, super.key});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Booking? booking;
    for (final item in ref.watch(bookingsProvider)) {
      if (item.id == bookingId) {
        booking = item;
        break;
      }
    }
    if (booking == null) {
      return const Scaffold(body: Center(child: Text('Booking not found.')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Booking confirmed')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.check_circle, size: 72),
          const SizedBox(height: 14),
          Text(
            booking.serviceTitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            booking.providerName,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.currency_rupee),
                  title: const Text('Agreed price'),
                  trailing: Text(
                    '₹${NumberFormat.decimalPattern('en_IN').format(booking.amountRupees.round())}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('Scheduled for'),
                  subtitle: Text(
                    DateFormat('EEEE, d MMM yyyy • h:mm a').format(booking.scheduledFor),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: const Text('Booking ID'),
                  subtitle: Text(booking.id),
                ),
                if (booking.bidEventId != null) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.gavel),
                    title: const Text('Accepted bid event'),
                    subtitle: Text(booking.bidEventId!),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                booking.source == BookingSource.acceptedBid
                    ? 'The booking keeps the exact accepted bid-event ID and price. Later provider bids cannot alter this agreement.'
                    : 'This booking snapshots the service listing price at the time of booking.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
