import 'package:bid_book/core/theme/app_theme.dart';
import 'package:bid_book/features/marketplace/application/remote_marketplace_controller.dart';
import 'package:bid_book/features/media/data/media_api.dart';
import 'package:bid_book/shared/widgets/photo_picker_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class PostRequestScreen extends ConsumerStatefulWidget {
  const PostRequestScreen({super.key});

  @override
  ConsumerState<PostRequestScreen> createState() => _PostRequestScreenState();
}

class _PostRequestScreenState extends ConsumerState<PostRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _area = TextEditingController();
  String _category = 'AC Service';
  DateTime _when = DateTime.now().add(const Duration(days: 1));
  bool _saving = false;
  List<XFile> _photos = const [];

  static const _categories = [
    'AC Service',
    'Electrician',
    'Plumber',
    'Cleaning',
    'Carpenter',
    'Appliance Repair',
    'Painter',
    'Labour',
    'Other',
  ];

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _area.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final request = await ref.read(remoteMarketplaceProvider.notifier).createRequest(
            title: _title.text.trim(),
            category: _category,
            description: _description.text.trim(),
            area: _area.text.trim(),
            requestedFor: _when,
          );
      if (_photos.isNotEmpty) {
        await ref.read(mediaApiProvider).uploadImages(
              entityType: 'request',
              entityId: request.id,
              files: _photos,
            );
        ref.invalidate(mediaGalleryProvider('request|${request.id}'));
      }
      if (mounted) context.go('/requests/${request.id}/bids');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _chooseDate() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _when,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (time == null) return;
    setState(() => _when = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Post a request')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.navyDeep, AppColors.navy]),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Color(0x22FFFFFF),
                      child: Icon(Icons.gavel_outlined, color: Colors.white),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Let providers compete for your job', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                          SizedBox(height: 4),
                          Text('Post once, compare transparent prices and accept the offer you prefer.', style: TextStyle(color: Color(0xFFD7E8FF), height: 1.35)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text('Job details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'What work do you need?',
                  hintText: 'e.g. Washing machine repair',
                  prefixIcon: Icon(Icons.home_repair_service_outlined),
                ),
                validator: (value) => (value?.trim().length ?? 0) < 3 ? 'Enter a clear job title.' : null,
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
                  labelText: 'Describe the work',
                  hintText: 'Tell providers what is wrong, size/quantity, and what should be included.',
                  alignLabelWithHint: true,
                ),
                validator: (value) => (value?.trim().length ?? 0) < 5 ? 'Add a little more detail so providers can price accurately.' : null,
              ),
              const SizedBox(height: 16),
              PhotoPickerField(
                files: _photos,
                onChanged: (value) => setState(() => _photos = value),
                title: 'Job photos',
                subtitle: 'Photos help providers understand the work and submit a better price.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _area,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Area / locality',
                  hintText: 'e.g. Sector 15, Sonipat',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (value) => (value?.trim().length ?? 0) < 2 ? 'Enter the job area.' : null,
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  onTap: _chooseDate,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: AppColors.blueSoft, borderRadius: BorderRadius.circular(13)),
                    child: const Icon(Icons.calendar_month_outlined, color: AppColors.blue),
                  ),
                  title: const Text('Preferred date & time', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(DateFormat('EEE, dd MMM • h:mm a').format(_when)),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: const Icon(Icons.campaign_outlined),
                label: Text(_saving ? 'Publishing request…' : 'Publish & start receiving bids'),
              ),
              const SizedBox(height: 10),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 15, color: AppColors.green),
                  SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      'Every bid and rebid stays permanently visible.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}
