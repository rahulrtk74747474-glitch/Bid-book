import 'package:bid_book/features/auth/application/auth_controller.dart';
import 'package:bid_book/features/bookings/application/booking_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final bookings = ref
        .watch(bookingsProvider)
        .where((booking) => booking.customerUserId == user?.id)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('My bookings')),
      body: bookings.isEmpty
          ? const Center(child: Text('No bookings yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: bookings.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final booking = bookings[index];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(
                      booking.serviceTitle,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${booking.providerName}\n${DateFormat('EEE, d MMM • h:mm a').format(booking.scheduledFor)}',
                    ),
                    isThreeLine: true,
                    trailing: Text(
                      '₹${NumberFormat.decimalPattern('en_IN').format(booking.amountRupees.round())}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    onTap: () => context.go('/bookings/${booking.id}'),
                  ),
                );
              },
            ),
    );
  }
}
