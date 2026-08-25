import 'dart:async';

import 'package:bid_book/features/auth/application/remote_auth_controller.dart';
import 'package:bid_book/features/communications/application/remote_communications_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  Timer? _poller;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _poller = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      ref.invalidate(remoteChatMessagesProvider(widget.chatId));
      ref.read(remoteCommunicationsProvider.notifier).refreshAll();
    });
  }

  @override
  void dispose() {
    _poller?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _messageController.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(remoteCommunicationsProvider.notifier).sendMessage(
            chatId: widget.chatId,
            body: body,
          );
      if (mounted) _messageController.clear();
    } catch (error) {
      if (mounted) {
        final message = ref
            .read(remoteCommunicationsProvider.notifier)
            .friendlyError(error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref
        .watch(remoteAuthControllerProvider)
        .asData
        ?.value
        .user
        ?.id;
    final communications = ref.watch(remoteCommunicationsProvider).asData?.value;
    final thread = communications?.chats
        .where((item) => item.id == widget.chatId)
        .firstOrNull;
    final messages = ref.watch(remoteChatMessagesProvider(widget.chatId));
    final time = DateFormat('h:mm a');
    final bookingLabel = thread?.bookingId;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(thread?.counterpartName ?? 'Chat'),
            if (bookingLabel != null)
              Text(
                'Booking ${bookingLabel.substring(0, 8)}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('$error')),
              data: (items) {
                if (items.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Start the conversation here. Keep job details and agreed changes inside Bid&Book.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(remoteChatMessagesProvider(widget.chatId));
                    await ref.read(remoteChatMessagesProvider(widget.chatId).future);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 20),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final mine = item.senderUserId == currentUserId;
                      return Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 330),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: Column(
                                crossAxisAlignment: mine
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Text(item.body),
                                  const SizedBox(height: 4),
                                  Text(
                                    time.format(item.createdAt),
                                    style: Theme.of(context).textTheme.labelSmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: 'Message',
                        prefixIcon: Icon(Icons.chat_bubble_outline),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send',
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
