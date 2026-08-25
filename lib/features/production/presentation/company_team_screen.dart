import 'package:bid_book/core/api/api_exception.dart';
import 'package:bid_book/features/production/data/production_api.dart';
import 'package:bid_book/features/production/domain/production_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CompanyTeamScreen extends ConsumerStatefulWidget {
  const CompanyTeamScreen({super.key, this.bookingId});

  final String? bookingId;

  @override
  ConsumerState<CompanyTeamScreen> createState() => _CompanyTeamScreenState();
}

class _CompanyTeamScreenState extends ConsumerState<CompanyTeamScreen> {
  bool _loading = true;
  Object? _error;
  List<ProviderStaffMember> _staff = const [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final staff = await ref.read(productionApiProvider).staff();
      if (mounted) setState(() => _staff = staff);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final phone = TextEditingController();
    var role = 'technician';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add team member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Bid&Book mobile number',
                  helperText: 'The staff member must already have an account.',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'manager', child: Text('Manager')),
                  DropdownMenuItem(value: 'dispatcher', child: Text('Dispatcher')),
                  DropdownMenuItem(value: 'technician', child: Text('Technician')),
                  DropdownMenuItem(value: 'accountant', child: Text('Accountant')),
                ],
                onChanged: (value) => setDialogState(() => role = value ?? role),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && phone.text.trim().isNotEmpty) {
      try {
        await ref.read(productionApiProvider).addStaff(
              phone: phone.text.trim(),
              role: role,
            );
        await _load();
      } catch (error) {
        if (mounted) _snack(error);
      }
    }
    phone.dispose();
  }

  Future<void> _remove(ProviderStaffMember member) async {
    try {
      await ref.read(productionApiProvider).removeStaff(member.userId);
      await _load();
    } catch (error) {
      if (mounted) _snack(error);
    }
  }

  Future<void> _assign(ProviderStaffMember member) async {
    final bookingId = widget.bookingId;
    if (bookingId == null) return;
    try {
      await ref.read(productionApiProvider).assignBooking(
            bookingId: bookingId,
            staffUserId: member.userId,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Assigned ${member.role} to the booking.')),
        );
      }
    } catch (error) {
      if (mounted) _snack(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bookingId == null ? 'Company team' : 'Assign technician'),
        actions: [
          IconButton(onPressed: _add, icon: const Icon(Icons.person_add_alt_1_outlined)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_message(_error!), textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      const Text(
                        'Company owners can add managers, dispatchers, technicians and accountants. Only explicitly assigned active technicians can start a job using the customer code.',
                      ),
                      const SizedBox(height: 16),
                      if (_staff.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(18),
                            child: Text('No staff members added yet.'),
                          ),
                        ),
                      ..._staff.map(
                        (member) => Card(
                          child: ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.badge_outlined)),
                            title: Text(member.role),
                            subtitle: Text('User ${_short(member.userId)}'),
                            trailing: widget.bookingId != null &&
                                    ['owner', 'manager', 'technician'].contains(member.role)
                                ? FilledButton.tonal(
                                    onPressed: () => _assign(member),
                                    child: const Text('Assign'),
                                  )
                                : IconButton(
                                    tooltip: 'Remove from team',
                                    onPressed: () => _remove(member),
                                    icon: const Icon(Icons.person_remove_outlined),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Add staff'),
      ),
    );
  }

  void _snack(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_message(error))),
    );
  }

  String _message(Object error) => error is ApiException ? error.message : '$error';
}

String _short(String value) => value.length <= 8 ? value : value.substring(0, 8).toUpperCase();
