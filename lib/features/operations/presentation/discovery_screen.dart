import 'package:bid_book/features/operations/data/operations_api.dart';
import 'package:bid_book/features/operations/domain/operations_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final _query = TextEditingController();
  final _area = TextEditingController();
  bool _verifiedOnly = false;
  String _sort = 'newest';
  int? _weekday;
  bool _loading = true;
  Object? _error;
  List<DiscoveryService> _results = const [];

  static const _days = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(_search);
  }

  @override
  void dispose() {
    _query.dispose();
    _area.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await ref.read(operationsApiProvider).discoverServices(
            query: _query.text,
            area: _area.text,
            verifiedOnly: _verifiedOnly,
            weekday: _weekday,
            sort: _sort,
          );
      if (mounted) setState(() => _results = results);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    return Scaffold(
      appBar: AppBar(title: const Text('Find services')),
      body: RefreshIndicator(
        onRefresh: _search,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            TextField(
              controller: _query,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: const InputDecoration(
                labelText: 'What service do you need?',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _area,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: const InputDecoration(
                labelText: 'Area / locality',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _verifiedOnly,
              onChanged: (value) => setState(() => _verifiedOnly = value),
              title: const Text('Verified providers only'),
            ),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _sort,
                    decoration: const InputDecoration(labelText: 'Sort'),
                    items: const [
                      DropdownMenuItem(value: 'newest', child: Text('Newest')),
                      DropdownMenuItem(value: 'price_low', child: Text('Price: low to high')),
                      DropdownMenuItem(value: 'price_high', child: Text('Price: high to low')),
                      DropdownMenuItem(value: 'rating', child: Text('Best rated')),
                    ],
                    onChanged: (value) => setState(() => _sort = value ?? 'newest'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    initialValue: _weekday,
                    decoration: const InputDecoration(labelText: 'Available day'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Any day')),
                      for (var index = 0; index < _days.length; index++)
                        DropdownMenuItem<int?>(value: index, child: Text(_days[index])),
                    ],
                    onChanged: (value) => setState(() => _weekday = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loading ? null : _search,
              icon: const Icon(Icons.tune),
              label: const Text('Search'),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Center(child: Padding(
                padding: EdgeInsets.all(36),
                child: CircularProgressIndicator(),
              ))
            else if (_error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text('$_error', textAlign: TextAlign.center),
                ),
              )
            else if (_results.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('No matching services found.'),
                ),
              )
            else
              ..._results.map((service) => Card(
                    child: ListTile(
                      onTap: () => context.push('/services/${service.id}'),
                      leading: CircleAvatar(
                        child: Icon(service.providerVerified
                            ? Icons.verified_user_outlined
                            : Icons.home_repair_service_outlined),
                      ),
                      title: Text(service.title),
                      subtitle: Text(
                        '${service.providerName}${service.providerVerified ? ' • Verified' : ''}\n'
                        '${service.category} • ${service.area}\n'
                        '${service.providerRating == null ? 'No completed-job rating yet' : '★ ${service.providerRating!.toStringAsFixed(1)} • ${service.providerReviewCount} review(s)'}',
                      ),
                      isThreeLine: true,
                      trailing: Text(
                        currency.format(service.priceRupees),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
