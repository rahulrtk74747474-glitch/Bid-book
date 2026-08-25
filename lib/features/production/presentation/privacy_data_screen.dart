import 'package:bid_book/core/api/api_client.dart';
import 'package:bid_book/core/api/api_exception.dart';
import 'package:bid_book/core/api/session_store.dart';
import 'package:bid_book/features/production/application/push_registration.dart';
import 'package:bid_book/features/production/data/production_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PrivacyDataScreen extends ConsumerStatefulWidget {
  const PrivacyDataScreen({super.key});

  @override
  ConsumerState<PrivacyDataScreen> createState() => _PrivacyDataScreenState();
}

class _PrivacyDataScreenState extends ConsumerState<PrivacyDataScreen> {
  bool _busy = false;
  Map<String, dynamic>? _export;

  Future<void> _enablePush() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final service = PushRegistrationService(
        ref.read(apiClientProvider),
        ref.read(sessionStoreProvider),
      );
      final enabled = await service.initializeAndRegister();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Push notifications are registered for this device.'
                : 'Push notifications could not be enabled. The in-app inbox still works.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) _show(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadExport() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final data = await ref.read(productionApiProvider).exportAccount();
      if (mounted) setState(() => _export = data);
    } catch (error) {
      if (mounted) _show(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final export = _export;
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & device setup')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Bid&Book keeps authentication tokens in secure device storage. Location is requested only for foreground nearby search/provider service-area setup. Background location is not required.',
              ),
            ),
          ),
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Enable push notifications'),
            subtitle: const Text('Receive new bids, booking changes, group updates and chat alerts.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _busy ? null : _enablePush,
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Prepare my data export'),
            subtitle: const Text('Review the categories of account and marketplace data held by Bid&Book.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _busy ? null : _loadExport,
          ),
          if (_busy) const LinearProgressIndicator(),
          if (export != null) ...[
            const SizedBox(height: 16),
            Text(
              'Export summary',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            _count('Services', export['services']),
            _count('Requests', export['requests']),
            _count('Bookings', export['bookings']),
            _count('Payments', export['payments']),
            _count('Payouts', export['payouts']),
            _count('Reviews', export['reviews']),
            _count('Disputes', export['disputes']),
            _count('Groups', export['groups']),
            _count('Notifications', export['notifications']),
            const SizedBox(height: 8),
            const Text(
              'This endpoint is the server-side foundation for a downloadable machine-readable export. Production support can package the returned JSON securely when required.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _count(String label, Object? value) {
    final count = value is List ? value.length : 0;
    return Card(
      child: ListTile(
        title: Text(label),
        trailing: Text('$count', style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }

  void _show(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error is ApiException ? error.message : error.toString()),
      ),
    );
  }
}
