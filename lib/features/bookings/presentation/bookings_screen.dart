import 'package:bid_book/features/marketplace/application/remote_marketplace_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marketplace = ref.watch(remoteMarketplaceProvider);
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final date = DateFormat('dd MMM yyyy, h:mm a');
    return Scaffold(
      appBar: AppBar(title: const Text('My bookings')),
      body: marketplace.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (data) => RefreshIndicator(
          onRefresh: () => ref.read(remoteMarketplaceProvider.notifier).refreshAll(),
          child: data.bookings.isEmpty
              ? const ListView(children: [SizedBox(height: 220), Center(child: Text('No bookings yet.'))])
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: data.bookings.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final booking = data.bookings[index];
                    return Card(
                      child: ListTile(
                        onTap: () => context.push('/bookings/${booking.id}'),
                        leading: const CircleAvatar(child: Icon(Icons.event_available_outlined)),
                        title: Text(currency.format(booking.agreedAmountRupees)),
                        subtitle: Text('${booking.area}\n${date.format(booking.scheduledFor)}'),
                        isThreeLine: true,
                        trailing: Text(booking.status.name),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
