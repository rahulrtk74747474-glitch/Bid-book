import 'package:bid_book/core/api/api_models.dart';
import 'package:bid_book/core/theme/app_theme.dart';
import 'package:bid_book/features/marketplace/application/remote_marketplace_controller.dart';
import 'package:bid_book/features/media/data/media_api.dart';
import 'package:bid_book/shared/widgets/photo_picker_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

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
  List<XFile> _photos = const [];

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
      final provider = await ref.read(remoteMarketplaceProvider.notifier).upsertProvider(
            kind: _kind,
            displayName: _name.text.trim(),
            serviceArea: _area.text.trim(),
            bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
          );
      if (_photos.isNotEmpty) {
        await ref.read(mediaApiProvider).uploadImages(
              entityType: 'provider',
              entityId: provider.id,
              files: _photos,
            );
        ref.invalidate(mediaGalleryProvider('provider|${provider.id}'));
      }
      if (mounted) context.go('/account');
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = ref.watch(remoteMarketplaceProvider).asData?.value.provider;
    return Scaffold(
      appBar: AppBar(title: Text(existing == null ? 'Become a provider' : 'Provider profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFDCE5F2)),
              ),
              child: const Row(
                children: [
                  CircleAvatar(
                    radius: 27,
                    backgroundColor: AppColors.greenSoft,
                    child: Icon(Icons.verified_user_outlined, color: AppColors.green, size: 29),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Build a profile customers can trust', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                        SizedBox(height: 4),
                        Text('Show your name, service area, experience and real work photos.', style: TextStyle(color: AppColors.muted, height: 1.35)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SegmentedButton<ApiProviderKind>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: ApiProviderKind.individual, icon: Icon(Icons.person_outline), label: Text('Individual')),
                ButtonSegment(value: ApiProviderKind.company, icon: Icon(Icons.business_outlined), label: Text('Company')),
              ],
              selected: {_kind},
              onSelectionChanged: (value) => setState(() => _kind = value.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: _kind == ApiProviderKind.company ? 'Business / company name' : 'Public provider name',
                prefixIcon: Icon(_kind == ApiProviderKind.company ? Icons.storefront_outlined : Icons.badge_outlined),
              ),
              validator: (value) => (value?.trim().length ?? 0) < 2 ? 'Enter a public name.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _area,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Primary service area',
                hintText: 'e.g. Sonipat and nearby',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              validator: (value) => (value?.trim().length ?? 0) < 2 ? 'Enter a service area.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bio,
              minLines: 4,
              maxLines: 7,
              decoration: const InputDecoration(
                labelText: 'About your work',
                hintText: 'Experience, specialities, tools, certifications and what customers can expect.',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            PhotoPickerField(
              files: _photos,
              onChanged: (value) => setState(() => _photos = value),
              title: 'Profile & portfolio photos',
              subtitle: 'Upload your profile, team, workshop or completed work photos.',
              maxImages: 6,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: AppColors.blueSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, color: AppColors.blue, size: 21),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Identity verification is separate. Bid&Book does not ask you to place raw Aadhaar details in your public provider profile.',
                      style: TextStyle(color: AppColors.navy, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.verified_outlined),
              label: Text(_saving ? 'Saving profile…' : existing == null ? 'Create provider profile' : 'Save provider profile'),
            ),
          ],
        ),
      ),
    );
  }
}
