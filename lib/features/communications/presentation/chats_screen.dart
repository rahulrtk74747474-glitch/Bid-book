import 'package:bid_book/core/theme/app_theme.dart';
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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chat'),
            Text('Booking-linked conversations', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.muted)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.push('/notifications'),
            icon: const Icon(Icons.notifications_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(remoteCommunicationsProvider.notifier).refreshAll(),
        child: communications.when(
          loading: () => ListView(children: const [SizedBox(height: 260), Center(child: CircularProgressIndicator())]),
          error: (error, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48, color: AppColors.muted),
              const SizedBox(height: 12),
              Text('$error', textAlign: TextAlign.center),
            ],
          ),
          data: (data) {
            if (data.chats.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 80),
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                    child: const Column(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: AppColors.blueSoft,
                          child: Icon(Icons.forum_outlined, size: 31, color: AppColors.blue),
                        ),
                        SizedBox(height: 13),
                        Text('No conversations yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        SizedBox(height: 6),
                        Text(
                          'Chats open from confirmed bookings, keeping service coordination connected to the job.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.muted, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              itemCount: data.chats.length,
              separatorBuilder: (_, _) => const SizedBox(height: 9),
              itemBuilder: (context, index) {
                final chat = data.chats[index];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    onTap: () => context.push('/chats/${chat.id}'),
                    leading: CircleAvatar(
                      radius: 25,
                      backgroundColor: chat.unreadCount > 0 ? AppColors.blueSoft : const Color(0xFFF2F4F7),
                      child: Icon(Icons.person_outline, color: chat.unreadCount > 0 ? AppColors.blue : AppColors.muted),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            chat.counterpartName,
                            style: TextStyle(fontWeight: chat.unreadCount > 0 ? FontWeight.w900 : FontWeight.w700),
                          ),
                        ),
                        const Icon(Icons.verified_user_outlined, size: 16, color: AppColors.green),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        chat.lastMessage?.isNotEmpty == true ? chat.lastMessage! : 'Secure booking conversation',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: chat.unreadCount > 0 ? AppColors.ink : AppColors.muted),
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (chat.lastMessageAt != null)
                          Text(date.format(chat.lastMessageAt!), style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
                        if (chat.unreadCount > 0) ...[
                          const SizedBox(height: 5),
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
