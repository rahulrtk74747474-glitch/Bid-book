class ApiNotification {
  const ApiNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.entityType,
    this.entityId,
    this.readAt,
  });

  final String id;
  final String kind;
  final String title;
  final String body;
  final String? entityType;
  final String? entityId;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isUnread => readAt == null;

  factory ApiNotification.fromJson(Map<String, dynamic> json) => ApiNotification(
        id: json['id'].toString(),
        kind: json['kind'] as String? ?? 'notification',
        title: json['title'] as String? ?? 'Bid&Book',
        body: json['body'] as String? ?? '',
        entityType: json['entity_type'] as String?,
        entityId: json['entity_id']?.toString(),
        readAt: _nullableDate(json['read_at']),
        createdAt: _date(json['created_at']),
      );
}

class ApiChatThread {
  const ApiChatThread({
    required this.id,
    required this.counterpartUserId,
    required this.counterpartName,
    required this.unreadCount,
    required this.createdAt,
    this.bookingId,
    this.requestId,
    this.lastMessage,
    this.lastMessageAt,
  });

  final String id;
  final String? bookingId;
  final String? requestId;
  final String counterpartUserId;
  final String counterpartName;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final DateTime createdAt;

  factory ApiChatThread.fromJson(Map<String, dynamic> json) => ApiChatThread(
        id: json['id'].toString(),
        bookingId: json['booking_id']?.toString(),
        requestId: json['request_id']?.toString(),
        counterpartUserId: json['counterpart_user_id'].toString(),
        counterpartName: json['counterpart_name'] as String? ?? 'Bid&Book user',
        lastMessage: json['last_message'] as String?,
        lastMessageAt: _nullableDate(json['last_message_at']),
        unreadCount: json['unread_count'] as int? ?? 0,
        createdAt: _date(json['created_at']),
      );
}

class ApiChatMessage {
  const ApiChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderUserId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final String senderUserId;
  final String body;
  final DateTime createdAt;

  factory ApiChatMessage.fromJson(Map<String, dynamic> json) => ApiChatMessage(
        id: json['id'].toString(),
        conversationId: json['conversation_id'].toString(),
        senderUserId: json['sender_user_id'].toString(),
        body: json['body'] as String? ?? '',
        createdAt: _date(json['created_at']),
      );
}

DateTime _date(Object? value) =>
    DateTime.tryParse(value?.toString() ?? '')?.toLocal() ?? DateTime.now();

DateTime? _nullableDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}
