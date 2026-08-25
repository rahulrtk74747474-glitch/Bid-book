import 'package:bid_book/core/api/api_models.dart';
import 'package:bid_book/features/marketplace/application/remote_marketplace_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AddServiceListingScreen extends ConsumerStatefulWidget {
  const AddServiceListingScreen({super.key});

  @override
  ConsumerState<AddServiceListingScreen> createState() => _AddServiceListingScreenState();
}

class _AddServiceListingScreenState extends ConsumerState<AddServiceListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _area = TextEditingController();
  final _price = TextEditingController();
  String _category = 'AC Service';
  ApiPricingUnit _unit = ApiPricingUnit.fixed;
  bool _saving = false;

  static const _categories = ['AC Service', 'Electrician', 'Plumber', 'Cleaning', 'Carpenter', 'Labour', 'Other'];

  @override
  void initState() {
    super.initState();
    _area.text = ref.read(remoteMarketplaceProvider).asData?.value.provider?.serviceArea ?? '';
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _area.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final rupees = double.tryParse(_price.text.trim());
    if (rupees == null || rupees <= 0) return;
    setState(() => _saving = true);
    try {
      final service = await ref.read(remoteMarketplaceProvider.notifier).createService(
            title: _title.text.trim(),
            category: _category,
            description: _description.text.trim(),
            area: _area.text.trim(),
            pricePaise: (rupees * 100).round(),
            pricingUnit: _unit,
          );
      if (mounted) context.go('/services/${service.id}');
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(remoteMarketplaceProvider).asData?.value.provider;
    if (provider == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Add service')),
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/provider/onboarding'),
            child: const Text('Create provider profile first'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Add service')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Publishing as ${provider.displayName}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Service title'),
              validator: (value) => (value?.trim().length ?? 0) < 2 ? 'Enter a title.' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: _categories.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
              onChanged: (value) => setState(() => _category = value ?? _category),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'Description / inclusions'),
              validator: (value) => (value?.trim().length ?? 0) < 2 ? 'Describe the service.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _area,
              decoration: const InputDecoration(labelText: 'Service area'),
              validator: (value) => (value?.trim().length ?? 0) < 2 ? 'Enter an area.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Price in ₹'),
              validator: (value) {
                final amount = double.tryParse(value?.trim() ?? '');
                return amount == null || amount <= 0 ? 'Enter a valid price.' : null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ApiPricingUnit>(
              value: _unit,
              decoration: const InputDecoration(labelText: 'Pricing basis'),
              items: ApiPricingUnit.values.map((unit) => DropdownMenuItem(value: unit, child: Text(unit.label))).toList(),
              onChanged: (value) => setState(() => _unit = value ?? _unit),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.publish_outlined),
              label: Text(_saving ? 'Publishing…' : 'Publish service'),
            ),
          ],
        ),
      ),
    );
  }
}
