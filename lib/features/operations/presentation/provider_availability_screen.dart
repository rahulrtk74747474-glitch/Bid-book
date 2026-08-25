import 'package:bid_book/features/operations/application/remote_operations_controller.dart';
import 'package:bid_book/features/operations/domain/operations_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProviderAvailabilityScreen extends ConsumerStatefulWidget {
  const ProviderAvailabilityScreen({super.key});

  @override
  ConsumerState<ProviderAvailabilityScreen> createState() =>
      _ProviderAvailabilityScreenState();
}

class _ProviderAvailabilityScreenState
    extends ConsumerState<ProviderAvailabilityScreen> {
  static const _days = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  final Set<int> _enabled = {};
  bool _initialized = false;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final operations = ref.watch(remoteOperationsProvider);
    final data = operations.asData?.value;
    if (!_initialized && data != null) {
      _initialized = true;
      _enabled.addAll(data.availability.where((slot) => slot.active).map((slot) => slot.weekday));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Provider availability')),
      body: operations.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (_) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Choose the days you normally accept work. This first version uses a standard 9:00 AM–5:00 PM window; detailed time slots can be expanded later without changing the backend model.',
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < _days.length; index++)
              SwitchListTile(
                value: _enabled.contains(index),
                title: Text(_days[index]),
                subtitle: Text(_enabled.contains(index) ? '9:00 AM – 5:00 PM' : 'Unavailable'),
                onChanged: (value) => setState(() {
                  if (value) {
                    _enabled.add(index);
                  } else {
                    _enabled.remove(index);
                  }
                }),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Saving…' : 'Save availability'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final slots = _enabled
          .map((weekday) => OpsAvailability(
                weekday: weekday,
                startMinute: 9 * 60,
                endMinute: 17 * 60,
                active: true,
              ))
          .toList()
        ..sort((a, b) => a.weekday.compareTo(b.weekday));
      await ref.read(remoteOperationsProvider.notifier).saveAvailability(slots);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Availability saved.')),
        );
      }
    } catch (error) {
      if (mounted) {
        final message = ref
            .read(remoteOperationsProvider.notifier)
            .friendlyError(error);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
