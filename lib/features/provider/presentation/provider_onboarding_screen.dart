import 'package:bid_book/core/api/api_models.dart';
import 'package:bid_book/features/marketplace/application/remote_marketplace_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProviderOnboardingScreen extends ConsumerStatefulWidget {
  const ProviderOnboardingScreen({super.key});

  @override
  ConsumerState<ProviderOnboardingScreen> createState() => _ProviderOnboardingScreenState();
}

class _ProviderOnboardingScreenState extends ConsumerState<ProviderOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _area = TextEditingController();
  final _bio = TextEditingController();
  ApiProviderKind _kind = ApiProviderKind.individual;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(remoteMarketplaceProvider).asData?.value.provider;
    if (existing != null) {
      _name.text = existing.displayName;
      _area.text = existing.serviceArea;
      _bio.text = existing.bio ?? '';
      _kind = existing.kind;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _area.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(remoteMarketplaceProvider.notifier).upsertProvider(
            kind: _kind,
            displayName: _name.text.trim(),
            serviceArea: _area.text.trim(),
            bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
          );
      if (mounted) context.go('/account');
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Provider profile')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<ApiProviderKind>(
                segments: ApiProviderKind.values
                    .map((kind) => ButtonSegment(value: kind, label: Text(kind.label)))
                    .toList(),
                selected: {_kind},
                onSelectionChanged: (value) => setState(() => _kind = value.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Public provider name'),
                validator: (value) => (value?.trim().length ?? 0) < 2 ? 'Enter a name.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _area,
                decoration: const InputDecoration(labelText: 'Service area'),
                validator: (value) => (value?.trim().length ?? 0) < 2 ? 'Enter a service area.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bio,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'About your work (optional)'),
              ),
              const SizedBox(height: 18),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('Identity verification is separate from provider onboarding. Bid&Book never stores raw Aadhaar data in this profile.'),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save provider profile'),
              ),
            ],
          ),
        ),
      );
}
