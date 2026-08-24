import 'package:bid_book/features/auth/application/auth_controller.dart';
import 'package:bid_book/features/provider/application/provider_profile_controller.dart';
import 'package:bid_book/features/provider/domain/provider_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProviderOnboardingScreen extends ConsumerStatefulWidget {
  const ProviderOnboardingScreen({super.key});

  @override
  ConsumerState<ProviderOnboardingScreen> createState() =>
      _ProviderOnboardingScreenState();
}

class _ProviderOnboardingScreenState
    extends ConsumerState<ProviderOnboardingScreen> {
  final _nameController = TextEditingController();
  final _areaController = TextEditingController(text: 'Sonipat');
  ProviderKind _kind = ProviderKind.individual;

  @override
  void dispose() {
    _nameController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existing = ref.watch(providerProfileProvider);
    if (existing != null && _nameController.text.isEmpty) {
      _nameController.text = existing.displayName;
      _areaController.text = existing.serviceArea;
      _kind = existing.kind;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Offer services')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Set up your provider profile',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Independent workers and companies use the same Bid&Book account. Identity verification is a separate trust step.',
          ),
          const SizedBox(height: 24),
          SegmentedButton<ProviderKind>(
            segments: ProviderKind.values
                .map(
                  (kind) => ButtonSegment(
                    value: kind,
                    label: Text(kind.label),
                    icon: Icon(
                      kind == ProviderKind.individual
                          ? Icons.person_outline
                          : Icons.business_outlined,
                    ),
                  ),
                )
                .toList(),
            selected: {_kind},
            onSelectionChanged: (selection) {
              setState(() => _kind = selection.first);
            },
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Public provider / business name',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _areaController,
            decoration: const InputDecoration(
              labelText: 'Primary service area',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 18),
          const Card(
            child: ListTile(
              leading: Icon(Icons.verified_user_outlined),
              title: Text('Identity status: pending'),
              subtitle: Text(
                'The production verification flow will store verification status, not raw Aadhaar numbers.',
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('Save provider profile'),
          ),
        ],
      ),
    );
  }

  void _save() {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;

    try {
      ref.read(providerProfileProvider.notifier).saveProfile(
            userId: user.id,
            displayName: _nameController.text,
            kind: _kind,
            serviceArea: _areaController.text,
          );
      context.go('/services/new');
    } on ArgumentError catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message?.toString() ?? 'Check your details.')),
      );
    }
  }
}
