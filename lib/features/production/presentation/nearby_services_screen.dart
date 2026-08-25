import 'package:bid_book/core/api/api_exception.dart';
import 'package:bid_book/features/production/application/location_service.dart';
import 'package:bid_book/features/production/data/production_api.dart';
import 'package:bid_book/features/production/domain/production_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class NearbyServicesScreen extends ConsumerStatefulWidget {
  const NearbyServicesScreen({super.key});

  @override
  ConsumerState<NearbyServicesScreen> createState() =>
      _NearbyServicesScreenState();
}

class _NearbyServicesScreenState extends ConsumerState<NearbyServicesScreen> {
  final _category = TextEditingController();
  bool _verifiedOnly = false;
  double _radiusKm = 25;
  bool _loading = false;
  Object? _error;
  BidBookLocation? _location;
  List<NearbyService> _services = const [];

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final location = _location ?? await const LocationService().currentLocation();
      final services = await ref.read(productionApiProvider).nearbyServices(
            latitude: location.latitude,
            longitude: location.longitude,
            radiusKm: _radiusKm.round(),
            category: _category.text,
            verifiedOnly: _verifiedOnly,
          );
      if (!mounted) return;
      setState(() {
        _location = location;
        _services = services;
      });
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
      appBar: AppBar(title: const Text('Nearby services')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const Text(
            'Bid&Book uses your foreground location only when you tap search. Providers are filtered by their configured service radius.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _category,
            decoration: const InputDecoration(
              labelText: 'Category (optional)',
              hintText: 'AC Service, Plumber, Electrician…',
            ),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Verified providers only'),
            value: _verifiedOnly,
            onChanged: (value) => setState(() => _verifiedOnly = value),
          ),
          Text('Search radius: ${_radiusKm.round()} km'),
          Slider(
            value: _radiusKm,
            min: 5,
            max: 100,
            divisions: 19,
            label: '${_radiusKm.round()} km',
            onChanged: (value) => setState(() => _radiusKm = value),
          ),
          FilledButton.icon(
            onPressed: _loading ? null : _search,
            icon: _loading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.near_me_outlined),
            label: const Text('Find nearby services'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error is ApiException
                  ? (_error as ApiException).message
                  : _error.toString(),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          if (_location != null)
            Text(
              '${_services.length} service(s) found',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          if (_location != null && _services.isEmpty && !_loading)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('No providers currently match this radius and filter.'),
              ),
            ),
          ..._services.map(
            (service) => Card(
              child: ListTile(
                onTap: () => context.push('/services/${service.id}'),
                leading: CircleAvatar(
                  child: Icon(
                    service.providerVerified
                        ? Icons.verified_user_outlined
                        : Icons.home_repair_service_outlined,
                  ),
                ),
                title: Text(service.title),
                subtitle: Text(
                  '${service.providerName}${service.providerVerified ? ' • Verified' : ''}\n'
                  '${service.distanceKm?.toStringAsFixed(1) ?? '?'} km • ${service.area}'
                  '${service.rating == null ? '' : ' • ⭐ ${service.rating!.toStringAsFixed(1)} (${service.reviewCount})'}',
                ),
                isThreeLine: true,
                trailing: Text(
                  currency.format(service.pricePaise / 100),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _category.dispose();
    super.dispose();
  }
}
