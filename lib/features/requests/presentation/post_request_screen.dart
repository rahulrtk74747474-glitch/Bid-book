import 'package:bid_book/features/auth/application/auth_controller.dart';
import 'package:bid_book/features/provider/application/provider_profile_controller.dart';
import 'package:bid_book/features/requests/application/request_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class PostRequestScreen extends ConsumerStatefulWidget {
  const PostRequestScreen({super.key});

  @override
  ConsumerState<PostRequestScreen> createState() => _PostRequestScreenState();
}

class _PostRequestScreenState extends ConsumerState<PostRequestScreen> {
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
  final _areaController = TextEditingController(text: 'Sonipat');
  String _category = _categories.first;
  late DateTime _requestedFor;

  @override
  void initState() {
    super.initState();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _requestedFor = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post a request')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Let nearby providers compete for your job',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 20),
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
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'What do you need?',
              hintText: 'Example: AC not cooling',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _descriptionController,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Add details that will help providers quote accurately.',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _areaController,
            decoration: const InputDecoration(
              labelText: 'Area',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: const Icon(Icons.event_outlined),
              title: const Text('Preferred date & time'),
              subtitle: Text(DateFormat('EEE, d MMM • h:mm a').format(_requestedFor)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _pickSchedule,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _publish,
            icon: const Icon(Icons.campaign_outlined),
            label: const Text('Open bidding'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickSchedule() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _requestedFor,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_requestedFor),
    );
    if (time == null) return;
    setState(() {
      _requestedFor = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _publish() {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;
    final provider = ref.read(providerProfileProvider);

    try {
      final request = ref.read(serviceRequestsProvider.notifier).createRequest(
            createdByUserId: user.id,
            createdByName: provider?.displayName ?? 'Customer',
            title: _titleController.text,
            category: _category,
            description: _descriptionController.text,
            area: _areaController.text,
            requestedFor: _requestedFor,
          );
      context.go('/requests/${request.id}/bids');
    } on ArgumentError catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message?.toString() ?? 'Check the request.')),
      );
    }
  }
}
