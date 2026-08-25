import 'package:bid_book/core/api/api_models.dart';
import 'package:bid_book/features/marketplace/application/remote_marketplace_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ServiceDetailScreen extends ConsumerStatefulWidget {
  const ServiceDetailScreen({super.key, required this.listingId});
  final String listingId;

  @override
  ConsumerState<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends ConsumerState<ServiceDetailScreen> {
  DateTime _scheduledFor = DateTime.now().add(const Duration(days: 1));
  bool _booking = false;

  Future<void> _book(ApiService service) async {
    setState(() => _booking = true);
    try {
      final booking = await ref.read(remoteMarketplaceProvider.notifier).directBook(
            listingId: service.id,
            scheduledFor: _scheduledFor,
            area: service.area,
          );
      if (mounted) context.go('/bookings/${booking.id}');
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _scheduledFor,
    );
    if (selected == null || !mounted) return;
    setState(() => _scheduledFor = DateTime(selected.year, selected.month, selected.day, 10));
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(remoteMarketplaceProvider).asData?.value;
    ApiService? service;
    for (final item in data?.services ?? const <ApiService>[]) {
      if (item.id == widget.listingId) {
        service = item;
        break;
      }
    }
    if (service == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Service')),
        body: const Center(child: Text('Service not found. Pull Home to refresh.')),
      );
    }

    final item = service;
    final isOwnProvider = data?.provider?.id == item.providerId;
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    return Scaffold(
      appBar: AppBar(title: Text(item.title)),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(item.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('${item.category} • ${item.area}'),
          const SizedBox(height: 6),
          Text(item.providerLabel),
          const SizedBox(height: 18),
          Text(item.description),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              title: Text(currency.format(item.priceRupees), style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(item.pricingUnit.label),
            ),
          ),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: _pickDate,
            leading: const Icon(Icons.event_outlined),
            title: const Text('Preferred booking date'),
            subtitle: Text(DateFormat('dd MMM yyyy').format(_scheduledFor)),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: isOwnProvider || _booking ? null : () => _book(item),
            icon: const Icon(Icons.book_online_outlined),
            label: Text(isOwnProvider ? 'This is your listing' : _booking ? 'Booking…' : 'Book service'),
          ),
        ],
      ),
    );
  }
}
