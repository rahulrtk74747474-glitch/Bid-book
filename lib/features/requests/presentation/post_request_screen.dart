import 'package:bid_book/features/marketplace/application/remote_marketplace_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

  static const _categories = ['AC Service', 'Electrician', 'Plumber', 'Cleaning', 'Carpenter', 'Labour', 'Other'];

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
      if (mounted) context.go('/requests/${request.id}/bids');
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
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
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_when));
    if (time == null) return;
    setState(() => _when = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Post a service request')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'What work do you need?'),
                validator: (value) => (value?.trim().length ?? 0) < 2 ? 'Enter a clear title.' : null,
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
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (value) => (value?.trim().length ?? 0) < 2 ? 'Describe the work.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _area,
                decoration: const InputDecoration(labelText: 'Area / locality'),
                validator: (value) => (value?.trim().length ?? 0) < 2 ? 'Enter an area.' : null,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Preferred date and time'),
                subtitle: Text(_when.toString()),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: _chooseDate,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: const Icon(Icons.campaign_outlined),
                label: Text(_saving ? 'Publishing…' : 'Publish request'),
              ),
            ],
          ),
        ),
      );
}
