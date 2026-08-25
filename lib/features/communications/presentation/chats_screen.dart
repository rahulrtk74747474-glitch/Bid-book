import 'package:bid_book/features/communications/application/remote_communications_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ChatsScreen extends ConsumerWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final communications = ref.watch(remoteCommunicationsProvider);
    final date = DateFormat('dd MMM, h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.push('/notifications'),
            icon: const Icon(Icons.notifications_outlined),
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
              const Icon(Icons.cloud_off_outlined, size: 48),
              const SizedBox(height: 12),
              Text('$error', textAlign: TextAlign.center),
            ],
          ),
          data: (data) {
            if (data.chats.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 120),
                  Icon(Icons.forum_outlined, size: 56),
                  SizedBox(height: 12),
                  Text(
                    'No conversations yet. Open a confirmed booking to start a secure chat.',
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
              itemCount: data.chats.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final chat = data.chats[index];
                return Card(
                  child: ListTile(
                    onTap: () => context.push('/chats/${chat.id}'),
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_outline),
                    ),
                    title: Text(
                      chat.counterpartName,
                      style: TextStyle(
                        fontWeight: chat.unreadCount > 0
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      chat.lastMessage?.isNotEmpty == true
                          ? chat.lastMessage!
                          : 'Booking conversation',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (chat.lastMessageAt != null)
                          Text(
                            date.format(chat.lastMessageAt!),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        if (chat.unreadCount > 0) ...[
                          const SizedBox(height: 4),
                          Badge.count(count: chat.unreadCount),
                        ],
                      ],
                    ),
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
