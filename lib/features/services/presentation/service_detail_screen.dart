import 'package:bid_book/features/auth/application/auth_controller.dart';
import 'package:bid_book/features/bookings/application/booking_controller.dart';
import 'package:bid_book/features/services/application/service_catalog_controller.dart';
import 'package:bid_book/features/services/domain/service_listing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ServiceDetailScreen extends ConsumerStatefulWidget {
  const ServiceDetailScreen({required this.listingId, super.key});

  final String listingId;

  @override
  ConsumerState<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends ConsumerState<ServiceDetailScreen> {
  late DateTime _scheduledFor;

  @override
  void initState() {
    super.initState();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _scheduledFor = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10);
  }

  @override
  Widget build(BuildContext context) {
    final listings = ref.watch(serviceCatalogProvider);
    ServiceListing? listing;
    for (final item in listings) {
      if (item.id == widget.listingId) {
        listing = item;
        break;
      }
    }
    final user = ref.watch(authControllerProvider).user;

    if (listing == null) {
      return const Scaffold(body: Center(child: Text('Service not found.')));
    }

    final isOwnListing = user?.id == listing.ownerUserId;
    return Scaffold(
      appBar: AppBar(title: Text(listing.category)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            listing.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  listing.providerName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (listing.identityVerified)
                const Icon(Icons.verified, size: 19),
            ],
          ),
          const SizedBox(height: 6),
          Text('★ ${listing.rating} • ${listing.area}'),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Text(
                    '₹${NumberFormat.decimalPattern('en_IN').format(listing.priceRupees.round())}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(width: 8),
                  Text(listing.pricingUnit.label),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(listing.description),
          const SizedBox(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: const Text('Requested date & time'),
            subtitle: Text(DateFormat('EEE, d MMM • h:mm a').format(_scheduledFor)),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: _pickSchedule,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: isOwnListing ? null : () => _book(listing!),
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(isOwnListing ? 'This is your listing' : 'Book service'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickSchedule() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledFor,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledFor),
    );
    if (time == null) return;
    setState(() {
      _scheduledFor = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _book(ServiceListing listing) {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;
    try {
      final booking = ref.read(bookingsProvider.notifier).createFromListing(
            listing: listing,
            customerUserId: user.id,
            scheduledFor: _scheduledFor,
          );
      context.go('/bookings/${booking.id}');
    } on StateError catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }
}
