import 'package:bid_book/features/communications/application/remote_communications_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final communications = ref.watch(remoteCommunicationsProvider);
    final date = DateFormat('dd MMM, h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: communications.asData?.value.unreadNotifications == 0
                ? null
                : () => ref
                    .read(remoteCommunicationsProvider.notifier)
                    .markAllNotificationsRead(),
            child: const Text('Read all'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(remoteCommunicationsProvider.notifier).refreshAll(),
        child: communications.when(
          loading: () => ListView(
            children: const [
              SizedBox(height: 260),
              Center(child: CircularProgressIndicator()),
            ],
          ),
          error: (error, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.notifications_off_outlined, size: 48),
              const SizedBox(height: 12),
              Text('$error', textAlign: TextAlign.center),
            ],
          ),
          data: (data) {
            if (data.notifications.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 120),
                  Icon(Icons.notifications_none, size: 56),
                  SizedBox(height: 12),
                  Text('No notifications yet.', textAlign: TextAlign.center),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
              itemCount: data.notifications.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final item = data.notifications[index];
                return Card(
                  child: ListTile(
                    onTap: item.isUnread
                        ? () => ref
                            .read(remoteCommunicationsProvider.notifier)
                            .markNotificationRead(item.id)
                        : null,
                    leading: CircleAvatar(
                      child: Icon(item.kind == 'chat_message'
                          ? Icons.chat_bubble_outline
                          : item.kind.contains('bid')
                              ? Icons.gavel_outlined
                              : item.kind.startsWith('group')
                                  ? Icons.groups_outlined
                                  : Icons.notifications_outlined),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontWeight: item.isUnread
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (item.isUnread)
                          const Badge(smallSize: 8),
                      ],
                    ),
                    subtitle: Text('${item.body}\n${date.format(item.createdAt)}'),
                    isThreeLine: true,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
