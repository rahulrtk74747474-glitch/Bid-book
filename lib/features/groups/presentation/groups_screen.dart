import 'package:bid_book/features/groups/application/remote_group_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  Future<void> _createGroup(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final area = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create neighborhood group'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Group name')),
          const SizedBox(height: 10),
          TextField(controller: area, decoration: const InputDecoration(labelText: 'Area / locality')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
        ],
      ),
    );
    if (result != true) return;
    try {
      final group = await ref.read(remoteGroupControllerProvider.notifier).createGroup(
            name: name.text.trim(),
            area: area.text.trim(),
          );
      if (context.mounted) context.push('/groups/${group.id}');
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _joinGroup(BuildContext context, WidgetRef ref) async {
    final code = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join group'),
        content: TextField(
          controller: code,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Invite code'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Join')),
        ],
      ),
    );
    if (result != true) return;
    try {
      await ref.read(remoteGroupControllerProvider.notifier).joinGroup(code.text);
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(remoteGroupControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Neighborhood groups'),
        actions: [
          IconButton(onPressed: () => _joinGroup(context, ref), icon: const Icon(Icons.group_add_outlined), tooltip: 'Join group'),
          IconButton(onPressed: () => _createGroup(context, ref), icon: const Icon(Icons.add_circle_outline), tooltip: 'Create group'),
        ],
      ),
      body: groups.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (data) => RefreshIndicator(
          onRefresh: () => ref.read(remoteGroupControllerProvider.notifier).refreshGroups(),
          child: data.groups.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 120),
                    const Icon(Icons.groups_2_outlined, size: 60),
                    const SizedBox(height: 12),
                    const Text('Create a local group or join one with an invite code.', textAlign: TextAlign.center),
                    const SizedBox(height: 18),
                    FilledButton(onPressed: () => _createGroup(context, ref), child: const Text('Create group')),
                    OutlinedButton(onPressed: () => _joinGroup(context, ref), child: const Text('Join with code')),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: data.groups.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final group = data.groups[index];
                    return Card(
                      child: ListTile(
                        onTap: () => context.push('/groups/${group.id}'),
                        leading: const CircleAvatar(child: Icon(Icons.apartment_outlined)),
                        title: Text(group.name),
                        subtitle: Text('${group.area}\nInvite: ${group.inviteCode}'),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
