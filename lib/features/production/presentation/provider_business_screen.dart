import 'package:bid_book/core/api/api_exception.dart';
import 'package:bid_book/features/production/application/location_service.dart';
import 'package:bid_book/features/production/data/production_api.dart';
import 'package:bid_book/features/production/domain/production_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProviderBusinessScreen extends ConsumerStatefulWidget {
  const ProviderBusinessScreen({super.key});

  @override
  ConsumerState<ProviderBusinessScreen> createState() =>
      _ProviderBusinessScreenState();
}

class _ProviderBusinessScreenState
    extends ConsumerState<ProviderBusinessScreen> {
  final _experience = TextEditingController();
  final _languages = TextEditingController();
  final _skills = TextEditingController();
  final _gstin = TextEditingController();
  final _radius = TextEditingController(text: '10');
  final _payoutReference = TextEditingController();
  final _payoutLabel = TextEditingController();
  final _headline = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  Object? _error;
  double? _latitude;
  double? _longitude;
  String? _providerId;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await ref.read(productionApiProvider).providerProfile();
      if (!mounted) return;
      _fill(profile);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _fill(ProductionProviderProfile profile) {
    _providerId = profile.providerId;
    _experience.text = '${profile.yearsExperience}';
    _languages.text = profile.languages.join(', ');
    _skills.text = profile.skills.join(', ');
    _gstin.text = profile.gstin ?? '';
    _radius.text = '${profile.serviceRadiusKm}';
    _payoutLabel.text = profile.payoutMethodLabel ?? '';
    _headline.text = profile.portfolioHeadline ?? '';
    _latitude = profile.latitude;
    _longitude = profile.longitude;
    setState(() {});
  }

  Future<void> _useCurrentLocation() async {
    try {
      final location = await const LocationService().currentLocation();
      if (!mounted) return;
      setState(() {
        _latitude = location.latitude;
        _longitude = location.longitude;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service-area location updated locally. Save to apply it.')),
      );
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final experience = int.tryParse(_experience.text.trim());
    final radius = int.tryParse(_radius.text.trim());
    if (experience == null || experience < 0 || radius == null || radius < 1) {
      _showError(const ApiException('Enter valid experience and service radius values.'));
      return;
    }
    setState(() => _saving = true);
    try {
      final profile = await ref.read(productionApiProvider).updateProviderProfile(
            yearsExperience: experience,
            languages: _commaList(_languages.text),
            skills: _commaList(_skills.text),
            gstin: _gstin.text,
            serviceRadiusKm: radius,
            latitude: _latitude,
            longitude: _longitude,
            payoutAccountReference: _payoutReference.text,
            payoutMethodLabel: _payoutLabel.text,
            portfolioHeadline: _headline.text,
          );
      if (!mounted) return;
      _fill(profile);
      _payoutReference.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Provider profile saved.')),
      );
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Provider business profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_message(_error!), textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    const Text(
                      'Complete the profile customers use to evaluate your experience, service area and business trust signals.',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _headline,
                      maxLength: 240,
                      decoration: const InputDecoration(labelText: 'Portfolio headline'),
                    ),
                    TextField(
                      controller: _experience,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Years of experience'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _languages,
                      decoration: const InputDecoration(labelText: 'Languages, comma separated'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _skills,
                      decoration: const InputDecoration(labelText: 'Skills, comma separated'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _gstin,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'GSTIN (businesses, if applicable)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _radius,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Service radius (km)',
                        helperText: 'Used for nearby discovery. Maximum 250 km.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Service-area location', style: TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            Text(
                              _latitude == null
                                  ? 'No precise provider location stored. Customers only see distance/service area, not raw coordinates.'
                                  : 'Location set • ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}',
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: _useCurrentLocation,
                              icon: const Icon(Icons.my_location),
                              label: const Text('Use current location'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Payout connection', style: TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            const Text(
                              'Store only the external payout provider token/reference here—never a card PIN, OTP or banking password.',
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _payoutLabel,
                              decoration: const InputDecoration(labelText: 'Payout method label'),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _payoutReference,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'New payout provider reference',
                                helperText: 'Leave blank to keep the existing reference.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: const Text('Save provider profile'),
                    ),
                    if (_providerId != null) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => context.push(
                          '/media?entityType=provider&entityId=$_providerId',
                        ),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Manage portfolio photos'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.push('/provider/team'),
                        icon: const Icon(Icons.groups_outlined),
                        label: const Text('Company team & technicians'),
                      ),
                    ],
                  ],
                ),
    );
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_message(error))),
    );
  }

  String _message(Object error) =>
      error is ApiException ? error.message : error.toString();

  @override
  void dispose() {
    _experience.dispose();
    _languages.dispose();
    _skills.dispose();
    _gstin.dispose();
    _radius.dispose();
    _payoutReference.dispose();
    _payoutLabel.dispose();
    _headline.dispose();
    super.dispose();
  }
}

List<String> _commaList(String raw) => raw
    .split(',')
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty)
    .toList(growable: false);
