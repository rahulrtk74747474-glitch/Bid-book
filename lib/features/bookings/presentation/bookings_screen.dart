import 'package:bid_book/core/api/api_models.dart';
import 'package:bid_book/core/theme/app_theme.dart';
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
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final date = DateFormat('dd MMM yyyy • h:mm a');
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bookings'),
            Text('Your confirmed and completed jobs', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.muted)),
          ],
        ),
      ),
      body: marketplace.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (data) => RefreshIndicator(
          onRefresh: () => ref.read(remoteMarketplaceProvider.notifier).refreshAll(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFDCE5F2)),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.blueSoft,
                      child: Icon(Icons.shield_outlined, color: AppColors.blue),
                    ),
                    SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Secure booking timeline', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                          SizedBox(height: 3),
                          Text('Payments, job start, completion and reviews stay connected to the booking.', style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.35)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (data.bookings.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        const Icon(Icons.calendar_month_outlined, size: 48, color: AppColors.blue),
                        const SizedBox(height: 10),
                        const Text('No bookings yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 5),
                        const Text('Book a listed service or accept a winning bid to create a booking.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                        const SizedBox(height: 15),
                        FilledButton(onPressed: () => context.go('/'), child: const Text('Find services')),
                      ],
                    ),
                  ),
                )
              else
                ...data.bookings.map((booking) => Padding(
                      padding: const EdgeInsets.only(bottom: 11),
                      child: Card(
                        child: InkWell(
                          onTap: () => context.push('/bookings/${booking.id}'),
                          borderRadius: BorderRadius.circular(22),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(color: _statusColor(booking.status).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(13)),
                                      child: Icon(_statusIcon(booking.status), color: _statusColor(booking.status)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(currency.format(booking.agreedAmountRupees), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.navy)),
                                          const SizedBox(height: 2),
                                          Text(booking.area, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                                      decoration: BoxDecoration(color: _statusColor(booking.status).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
                                      child: Text(_statusLabel(booking.status), style: TextStyle(color: _statusColor(booking.status), fontSize: 10.5, fontWeight: FontWeight.w900)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.muted),
                                    const SizedBox(width: 5),
                                    Expanded(child: Text(date.format(booking.scheduledFor), style: const TextStyle(fontSize: 12.5, color: AppColors.muted, fontWeight: FontWeight.w600))),
                                    const Icon(Icons.chevron_right, color: AppColors.muted),
                                  ],
                                ),
                                if (booking.acceptedBidEventId != null) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                    decoration: BoxDecoration(color: AppColors.orangeSoft, borderRadius: BorderRadius.circular(12)),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.gavel_outlined, size: 16, color: AppColors.orange),
                                        SizedBox(width: 6),
                                        Text('Created from an accepted transparent bid', style: TextStyle(color: AppColors.orange, fontSize: 11.5, fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }

  static Color _statusColor(ApiBookingStatus status) => switch (status) {
        ApiBookingStatus.confirmed => AppColors.blue,
        ApiBookingStatus.inProgress => AppColors.orange,
        ApiBookingStatus.completed => AppColors.green,
        ApiBookingStatus.cancelled => const Color(0xFFB42318),
      };

  static IconData _statusIcon(ApiBookingStatus status) => switch (status) {
        ApiBookingStatus.confirmed => Icons.event_available_outlined,
        ApiBookingStatus.inProgress => Icons.handyman_outlined,
        ApiBookingStatus.completed => Icons.check_circle_outline,
        ApiBookingStatus.cancelled => Icons.cancel_outlined,
      };

  static String _statusLabel(ApiBookingStatus status) => switch (status) {
        ApiBookingStatus.confirmed => 'CONFIRMED',
        ApiBookingStatus.inProgress => 'IN PROGRESS',
        ApiBookingStatus.completed => 'COMPLETED',
        ApiBookingStatus.cancelled => 'CANCELLED',
      };
}
