import 'package:bid_book/core/api/api_exception.dart';
import 'package:bid_book/core/api/bidbook_api.dart';
import 'package:bid_book/features/auth/application/remote_auth_controller.dart';
import 'package:bid_book/features/communications/domain/communication_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final remoteCommunicationsProvider = AsyncNotifierProvider<
    RemoteCommunicationsController,
    RemoteCommunicationsState>(RemoteCommunicationsController.new);

final remoteChatMessagesProvider =
    FutureProvider.family<List<ApiChatMessage>, String>((ref, chatId) async {
  final auth = ref.watch(remoteAuthControllerProvider).asData?.value;
  if (auth?.isAuthenticated != true) return const [];
  return ref.read(bidBookApiProvider).chatMessages(chatId);
});

class RemoteCommunicationsState {
  const RemoteCommunicationsState({
    this.notifications = const [],
    this.chats = const [],
    this.unreadNotifications = 0,
  });

  final List<ApiNotification> notifications;
  final List<ApiChatThread> chats;
  final int unreadNotifications;

  int get unreadChats =>
      chats.fold(0, (total, chat) => total + chat.unreadCount);

  RemoteCommunicationsState copyWith({
    List<ApiNotification>? notifications,
    List<ApiChatThread>? chats,
    int? unreadNotifications,
  }) =>
      RemoteCommunicationsState(
        notifications: notifications ?? this.notifications,
        chats: chats ?? this.chats,
        unreadNotifications: unreadNotifications ?? this.unreadNotifications,
      );
}

class RemoteCommunicationsController
    extends AsyncNotifier<RemoteCommunicationsState> {
  BidBookApi get _api => ref.read(bidBookApiProvider);

  @override
  Future<RemoteCommunicationsState> build() async {
    final auth = ref.watch(remoteAuthControllerProvider).asData?.value;
    if (auth?.isAuthenticated != true) {
      return const RemoteCommunicationsState();
    }
    return _loadAll();
  }

  Future<RemoteCommunicationsState> _loadAll() async {
    final notifications = await _api.notifications();
    final chats = await _api.chats();
    final unread = await _api.unreadNotificationCount();
    return RemoteCommunicationsState(
      notifications: notifications,
      chats: chats,
      unreadNotifications: unread,
    );
  }

  Future<void> refreshAll() async {
    try {
      state = AsyncData(await _loadAll());
    } catch (error, stack) {
      state = AsyncError<RemoteCommunicationsState>(error, stack);
    }
  }

  Future<ApiChatThread> openBookingChat(String bookingId) async {
    final chat = await _api.chatFromBooking(bookingId);
    final current = state.asData?.value ?? const RemoteCommunicationsState();
    final chats = [chat, ...current.chats.where((item) => item.id != chat.id)];
    state = AsyncData(current.copyWith(chats: chats));
    return chat;
  }

  Future<ApiChatMessage> sendMessage({
    required String chatId,
    required String body,
  }) async {
    final message = await _api.sendChatMessage(chatId: chatId, body: body);
    ref.invalidate(remoteChatMessagesProvider(chatId));
    await refreshAll();
    return message;
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _api.markNotificationRead(notificationId);
    await refreshAll();
  }

  Future<void> markAllNotificationsRead() async {
    await _api.markAllNotificationsRead();
    await refreshAll();
  }

  String friendlyError(Object error) =>
      error is ApiException ? error.message : 'Something went wrong. Please try again.';
}
