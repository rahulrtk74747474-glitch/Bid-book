import 'package:bid_book/core/api/api_models.dart';
import 'package:bid_book/features/communications/application/remote_communications_controller.dart';
import 'package:bid_book/features/marketplace/application/remote_marketplace_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class BookingDetailScreen extends ConsumerWidget {
  const BookingDetailScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(remoteMarketplaceProvider).asData?.value;
    ApiBooking? booking;
    for (final item in data?.bookings ?? const <ApiBooking>[]) {
      if (item.id == bookingId) {
        booking = item;
        break;
      }
    }
    if (booking == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking')),
        body: const Center(child: Text('Booking not found.')),
      );
    }
    final value = booking;
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final date = DateFormat('dd MMM yyyy, h:mm a');
    return Scaffold(
      appBar: AppBar(title: const Text('Booking confirmation')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Icon(Icons.verified_outlined, size: 64),
          const SizedBox(height: 12),
          Text(
            'Booking ${value.status.name}',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 24),
          _row('Status', value.status.name),
          _row('Agreed amount', currency.format(value.agreedAmountRupees)),
          _row('Scheduled for', date.format(value.scheduledFor)),
          _row('Area', value.area),
          _row('Provider ID', value.providerId),
          if (value.acceptedBidEventId != null)
            _row('Accepted bid event', value.acceptedBidEventId!),
          if (value.requestId != null) _row('Request', value.requestId!),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.push('/bookings/${value.id}/trust'),
            icon: const Icon(Icons.shield_outlined),
            label: const Text('Payment, trust, review & dispute'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              try {
                final chat = await ref
                    .read(remoteCommunicationsProvider.notifier)
                    .openBookingChat(value.id);
                if (context.mounted) context.push('/chats/${chat.id}');
              } catch (error) {
                if (context.mounted) {
                  final message = ref
                      .read(remoteCommunicationsProvider.notifier)
                      .friendlyError(error);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(message)),
                  );
                }
              }
            },
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Message booking participant'),
          ),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Keep job coordination and payment state inside Bid&Book. The agreed amount is a server-side snapshot, so later bid changes cannot alter this booking price.',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(child: SelectableText(value)),
          ],
        ),
      );
}
