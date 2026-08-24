import 'package:bid_book/features/provider/application/provider_profile_controller.dart';
import 'package:bid_book/features/provider/domain/provider_profile.dart';
import 'package:bid_book/features/services/application/service_catalog_controller.dart';
import 'package:bid_book/features/services/domain/service_listing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AddServiceListingScreen extends ConsumerStatefulWidget {
  const AddServiceListingScreen({super.key});

  @override
  ConsumerState<AddServiceListingScreen> createState() =>
      _AddServiceListingScreenState();
}

class _AddServiceListingScreenState
    extends ConsumerState<AddServiceListingScreen> {
  static const _categories = [
    'AC Service',
    'Electrician',
    'Plumber',
    'Cleaning',
    'Carpenter',
    'Labour',
    'Other',
  ];

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _areaController = TextEditingController();
  String _category = _categories.first;
  PricingUnit _pricingUnit = PricingUnit.fixed;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(providerProfileProvider);
    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Add service')),
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/provider/onboarding'),
            child: const Text('Set up provider profile first'),
          ),
        ),
      );
    }
    if (_areaController.text.isEmpty) {
      _areaController.text = profile.serviceArea;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Post a service')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Service title',
              hintText: 'Example: Split AC general service',
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: _categories
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (value) => setState(() => _category = value!),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _descriptionController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'What is included?',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Price',
              prefixText: '₹ ',
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<PricingUnit>(
            initialValue: _pricingUnit,
            decoration: const InputDecoration(labelText: 'Pricing type'),
            items: PricingUnit.values
                .map(
                  (unit) => DropdownMenuItem(
                    value: unit,
                    child: Text(unit.label),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _pricingUnit = value!),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _areaController,
            decoration: const InputDecoration(
              labelText: 'Service location / area',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _save(profile),
            icon: const Icon(Icons.publish_outlined),
            label: const Text('Publish service'),
          ),
        ],
      ),
    );
  }

  void _save(ProviderProfile profile) {
    final rupees = int.tryParse(_priceController.text.trim());
    if (rupees == null || rupees <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid price.')),
      );
      return;
    }

    try {
      ref.read(serviceCatalogProvider.notifier).addListing(
            provider: profile,
            title: _titleController.text,
            category: _category,
            description: _descriptionController.text,
            area: _areaController.text,
            pricePaise: rupees * 100,
            pricingUnit: _pricingUnit,
          );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service published.')),
      );
      context.go('/account');
    } on ArgumentError catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message?.toString() ?? 'Check the service details.')),
      );
    }
  }
}
