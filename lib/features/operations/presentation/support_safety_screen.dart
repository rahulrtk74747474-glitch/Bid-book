import 'package:bid_book/features/auth/application/remote_auth_controller.dart';
import 'package:bid_book/features/operations/application/remote_operations_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class SupportSafetyScreen extends ConsumerWidget {
  const SupportSafetyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final operations = ref.watch(remoteOperationsProvider);
    final date = DateFormat('dd MMM yyyy, h:mm a');
    return Scaffold(
      appBar: AppBar(title: const Text('Support & safety')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(remoteOperationsProvider.notifier).refreshAll(),
        child: operations.when(
          loading: () => ListView(children: const [
            SizedBox(height: 280),
            Center(child: CircularProgressIndicator()),
          ]),
          error: (error, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('$error', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(remoteOperationsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
          data: (data) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Get help', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      const Text('Create a support case for account, booking, payment or provider issues.'),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => _supportDialog(context, ref),
                        icon: const Icon(Icons.support_agent),
                        label: const Text('Open support case'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Report a safety issue', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      const Text('Report scams, harassment, fake services, unsafe behavior or suspicious accounts for review.'),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _reportDialog(context, ref),
                        icon: const Icon(Icons.flag_outlined),
                        label: const Text('Create report'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('My support cases', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              if (data.supportCases.isEmpty)
                const Text('No support cases yet.')
              else
                ...data.supportCases.map((item) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.support_agent),
                        title: Text(item.subject),
                        subtitle: Text('${item.category} • ${item.status}\n${date.format(item.createdAt)}'),
                        isThreeLine: true,
                      ),
                    )),
              const SizedBox(height: 20),
              Text('My reports', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              if (data.reports.isEmpty)
                const Text('No safety reports yet.')
              else
                ...data.reports.map((item) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.flag_outlined),
                        title: Text(item.category),
                        subtitle: Text('${item.entityType} • ${item.status}\n${item.summary}'),
                        isThreeLine: true,
                      ),
                    )),
              const SizedBox(height: 28),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Delete Bid&Book account', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      const Text('This signs you out, revokes active sessions and deactivates the account. Transaction and safety records may still be retained where legally or operationally required.'),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _deleteAccount(context, ref),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete account'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _supportDialog(BuildContext context, WidgetRef ref) async {
    final subject = TextEditingController();
    final category = TextEditingController(text: 'general');
    final description = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Open support case'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: subject, decoration: const InputDecoration(labelText: 'Subject')),
              const SizedBox(height: 10),
              TextField(controller: category, decoration: const InputDecoration(labelText: 'Category')),
              const SizedBox(height: 10),
              TextField(controller: description, maxLines: 5, decoration: const InputDecoration(labelText: 'Describe the issue')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Submit')),
        ],
      ),
    );
    if (submit == true && context.mounted) {
      try {
        await ref.read(remoteOperationsProvider.notifier).createSupportCase(
              subject: subject.text.trim(),
              category: category.text.trim(),
              description: description.text.trim(),
            );
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Support case created.')));
      } catch (error) {
        if (context.mounted) _error(context, ref, error);
      }
    }
    subject.dispose();
    category.dispose();
    description.dispose();
  }

  Future<void> _reportDialog(BuildContext context, WidgetRef ref) async {
    var entityType = 'user';
    final entityId = TextEditingController();
    final category = TextEditingController(text: 'safety');
    final summary = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create safety report'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: entityType,
                  decoration: const InputDecoration(labelText: 'Report type'),
                  items: const [
                    DropdownMenuItem(value: 'user', child: Text('User')),
                    DropdownMenuItem(value: 'provider', child: Text('Provider')),
                    DropdownMenuItem(value: 'service', child: Text('Service')),
                    DropdownMenuItem(value: 'booking', child: Text('Booking')),
                    DropdownMenuItem(value: 'message', child: Text('Message')),
                    DropdownMenuItem(value: 'review', child: Text('Review')),
                  ],
                  onChanged: (value) => setState(() => entityType = value ?? 'user'),
                ),
                const SizedBox(height: 10),
                TextField(controller: entityId, decoration: const InputDecoration(labelText: 'User / booking / item ID')),
                const SizedBox(height: 10),
                TextField(controller: category, decoration: const InputDecoration(labelText: 'Category')),
                const SizedBox(height: 10),
                TextField(controller: summary, maxLines: 4, decoration: const InputDecoration(labelText: 'What happened?')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Report')),
          ],
        ),
      ),
    );
    if (submit == true && context.mounted) {
      try {
        await ref.read(remoteOperationsProvider.notifier).createReport(
              entityType: entityType,
              entityId: entityId.text.trim(),
              category: category.text.trim(),
              summary: summary.text.trim(),
            );
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted for review.')));
      } catch (error) {
        if (context.mounted) _error(context, ref, error);
      }
    }
    entityId.dispose();
    category.dispose();
    summary.dispose();
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text('This action deactivates your Bid&Book account and signs out all active sessions. Type deletion is not reversible from the app.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete account')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(remoteOperationsProvider.notifier).deleteAccount();
      await ref.read(remoteAuthControllerProvider.notifier).signOut();
      if (context.mounted) context.go('/login');
    } catch (error) {
      if (context.mounted) _error(context, ref, error);
    }
  }

  void _error(BuildContext context, WidgetRef ref, Object error) {
    final message = ref.read(remoteOperationsProvider.notifier).friendlyError(error);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
