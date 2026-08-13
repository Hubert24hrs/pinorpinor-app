import 'enums.dart';
import 'json.dart';
import 'media_item.dart';

/// The other member in a conversation, as `/api/conversations` shapes them.
class ConversationPartner {
  const ConversationPartner({
    required this.id,
    required this.username,
    required this.displayName,
    this.verificationStatus = VerificationStatus.none,
    this.isAvailableToday = false,
    this.avatarUrl,
  });

  final String id;
  final String username;
  final String displayName;
  final VerificationStatus verificationStatus;
  final bool isAvailableToday;
  final String? avatarUrl;

  bool get isVerified => verificationStatus.isVerified;

  factory ConversationPartner.fromJson(Map<String, dynamic> json) {
    final media = MediaItem.listFrom(json['media']);
    return ConversationPartner(
      id: asString(json['id']),
      username: asString(json['username']),
      displayName: asString(
        json['displayName'],
        fallback: asString(json['username']),
      ),
      verificationStatus: VerificationStatus.parse(json['verificationStatus']),
      isAvailableToday: asBool(
        asMap(json['datingProfile'])['isAvailableToday'],
      ),
      avatarUrl: media.isEmpty ? null : media.first.url,
    );
  }
}

class ConversationSummary {
  const ConversationSummary({
    required this.conversationId,
    required this.updatedAt,
    this.partner,
    this.lastMessagePreview,
    this.lastMessageAt,
    this.lastMessageSenderId,
    this.lastReadAt,
    this.matchId,
    this.isUnmatched = false,
  });

  final String conversationId;
  final DateTime updatedAt;
  final ConversationPartner? partner;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;
  final String? lastMessageSenderId;
  final DateTime? lastReadAt;
  final String? matchId;

  /// True once either side has unmatched. The thread stays readable but the
  /// send route refuses new messages, so the composer is disabled to match.
  final bool isUnmatched;

  /// Unread is derived from `lastReadAt` against the last message, because the
  /// backend tracks read state per member rather than per message.
  bool unreadFor(String currentUserId) {
    final at = lastMessageAt;
    if (at == null) return false;
    if (lastMessageSenderId == currentUserId) return false;
    final read = lastReadAt;
    return read == null || read.isBefore(at);
  }

  factory ConversationSummary.fromJson(Map<String, dynamic> json) {
    final last = asMap(json['lastMessage']);
    final partnerJson = asMap(json['partner']);
    final deleted = asBool(last['isDeleted']);

    return ConversationSummary(
      conversationId: asString(json['conversationId']),
      updatedAt: asDate(json['updatedAt']),
      partner: partnerJson.isEmpty
          ? null
          : ConversationPartner.fromJson(partnerJson),
      lastMessagePreview: deleted
          ? 'Message deleted'
          : asStringOrNull(last['content']) ??
                (last.isEmpty ? null : 'Sent a photo'),
      lastMessageAt: asDateOrNull(last['createdAt']),
      lastMessageSenderId: asStringOrNull(last['senderId']),
      lastReadAt: asDateOrNull(json['lastReadAt']),
      matchId: asStringOrNull(json['matchId']),
      isUnmatched: asBool(json['isUnmatched']),
    );
  }

  static List<ConversationSummary> listFrom(Object? value) => asMapList(
    value,
  ).map(ConversationSummary.fromJson).toList(growable: false);
}

class Message {
  const Message({
    required this.id,
    required this.senderId,
    required this.createdAt,
    this.content,
    this.mediaUrl,
    this.status = MessageStatus.sent,
    this.senderName,
    this.isPending = false,
    this.failed = false,
  });

  final String id;
  final String senderId;
  final DateTime createdAt;
  final String? content;
  final String? mediaUrl;
  final MessageStatus status;
  final String? senderName;

  /// Optimistic local echo — rendered immediately, replaced when the POST
  /// returns. Keeps the thread responsive on a slow connection.
  final bool isPending;

  final bool failed;

  bool isMine(String currentUserId) => senderId == currentUserId;

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: asString(json['id']),
    senderId: asString(json['senderId']),
    createdAt: asDate(json['createdAt']),
    content: asStringOrNull(json['content']),
    mediaUrl: asStringOrNull(json['mediaUrl']),
    status: MessageStatus.parse(json['status']),
    senderName: asStringOrNull(asMap(json['sender'])['displayName']),
  );

  Message copyWith({bool? isPending, bool? failed}) => Message(
    id: id,
    senderId: senderId,
    createdAt: createdAt,
    content: content,
    mediaUrl: mediaUrl,
    status: status,
    senderName: senderName,
    isPending: isPending ?? this.isPending,
    failed: failed ?? this.failed,
  );

  static List<Message> listFrom(Object? value) =>
      asMapList(value).map(Message.fromJson).toList(growable: false);
}

/// One page of history. `nextCursor` is the id to pass back for older messages;
/// null means the top of the thread has been reached.
class MessagePage {
  const MessagePage({required this.messages, this.nextCursor});

  final List<Message> messages;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;

  factory MessagePage.fromJson(Map<String, dynamic> json) => MessagePage(
    messages: Message.listFrom(json['messages']),
    nextCursor: asStringOrNull(json['nextCursor']),
  );
}

class MatchSummary {
  const MatchSummary({
    required this.matchId,
    required this.conversationId,
    required this.createdAt,
    this.partner,
    this.lastMessagePreview,
    this.lastMessageAt,
  });

  final String matchId;
  final String conversationId;
  final DateTime createdAt;
  final ConversationPartner? partner;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;

  factory MatchSummary.fromJson(Map<String, dynamic> json) {
    final last = asMap(json['lastMessage']);
    final partnerJson = asMap(json['partner']);
    return MatchSummary(
      matchId: asString(json['matchId']),
      conversationId: asString(json['conversationId']),
      createdAt: asDate(json['createdAt']),
      partner: partnerJson.isEmpty
          ? null
          : ConversationPartner.fromJson(partnerJson),
      lastMessagePreview: asStringOrNull(last['content']),
      lastMessageAt: asDateOrNull(last['createdAt']),
    );
  }

  static List<MatchSummary> listFrom(Object? value) =>
      asMapList(value).map(MatchSummary.fromJson).toList(growable: false);
}

/// Result of `POST /api/swipe`.
class SwipeResult {
  const SwipeResult({required this.matched, this.matchId, this.conversationId});

  final bool matched;
  final String? matchId;
  final String? conversationId;

  factory SwipeResult.fromJson(Map<String, dynamic> json) => SwipeResult(
    matched: asBool(json['matched']),
    matchId: asStringOrNull(json['matchId']),
    conversationId: asStringOrNull(json['conversationId']),
  );
}
