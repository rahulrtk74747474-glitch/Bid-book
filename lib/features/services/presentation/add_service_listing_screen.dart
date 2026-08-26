import 'package:bid_book/core/api/api_models.dart';
import 'package:bid_book/core/theme/app_theme.dart';
import 'package:bid_book/features/marketplace/application/remote_marketplace_controller.dart';
import 'package:bid_book/features/media/data/media_api.dart';
import 'package:bid_book/shared/widgets/photo_picker_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

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
  List<XFile> _photos = const [];

  static const _categories = [
    'AC Service', 'Electrician', 'Plumber', 'Cleaning', 'Carpenter',
    'Appliance Repair', 'Painter', 'Labour', 'Other'
  ];

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
      if (_photos.isNotEmpty) {
        await ref.read(mediaApiProvider).uploadImages(
              entityType: 'service',
              entityId: service.id,
              files: _photos,
            );
        ref.invalidate(mediaGalleryProvider('service|${service.id}'));
      }
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
        appBar: AppBar(title: const Text('Publish a service')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_user_outlined, size: 58, color: AppColors.blue),
                const SizedBox(height: 14),
                const Text('Create your provider profile first', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text('Your provider name, service area and work profile are shown to customers.', textAlign: TextAlign.center),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => context.go('/provider/onboarding'),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Create provider profile'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Publish a service')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.greenSoft,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFB7E8D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified, color: AppColors.green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Publishing as ${provider.displayName}',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.green),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Service title',
                hintText: 'e.g. Split AC deep service',
                prefixIcon: Icon(Icons.home_repair_service_outlined),
              ),
              validator: (value) => (value?.trim().length ?? 0) < 3 ? 'Enter a clear title.' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category_outlined)),
              items: _categories.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
              onChanged: (value) => setState(() => _category = value ?? _category),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              minLines: 4,
              maxLines: 7,
              decoration: const InputDecoration(
                labelText: 'What is included?',
                hintText: 'Explain your service, exclusions, materials and typical completion time.',
                alignLabelWithHint: true,
              ),
              validator: (value) => (value?.trim().length ?? 0) < 5 ? 'Describe what customers receive.' : null,
            ),
            const SizedBox(height: 16),
            PhotoPickerField(
              files: _photos,
              onChanged: (value) => setState(() => _photos = value),
              title: 'Service & work photos',
              subtitle: 'Real work photos build trust and make your listing stand out.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _area,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Service area', prefixIcon: Icon(Icons.location_on_outlined)),
              validator: (value) => (value?.trim().length ?? 0) < 2 ? 'Enter your service area.' : null,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Starting price', prefixText: '₹ '),
                    validator: (value) {
                      final amount = double.tryParse(value?.trim() ?? '');
                      return amount == null || amount <= 0 ? 'Enter a valid price.' : null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 4,
                  child: DropdownButtonFormField<ApiPricingUnit>(
                    initialValue: _unit,
                    decoration: const InputDecoration(labelText: 'Pricing basis'),
                    items: ApiPricingUnit.values.map((unit) => DropdownMenuItem(value: unit, child: Text(unit.label))).toList(),
                    onChanged: (value) => setState(() => _unit = value ?? _unit),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.publish_outlined),
              label: Text(_saving ? 'Publishing service…' : 'Publish service'),
            ),
            const SizedBox(height: 10),
            const Text(
              'Customers will see your provider profile, photos and transparent starting price.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
