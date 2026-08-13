import 'enums.dart';
import 'json.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    this.data = const <String, dynamic>{},
  });

  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  /// Free-form payload the backend attaches, e.g.
  /// `{ conversationId, fromUserId }` or `{ contactRequestId }`. Used to build
  /// the in-app destination when the row is tapped.
  final Map<String, dynamic> data;

  String? get conversationId => asStringOrNull(data['conversationId']);
  String? get contactRequestId => asStringOrNull(data['contactRequestId']);
  String? get fromUserId => asStringOrNull(data['fromUserId']);
  String? get ownerUsername => asStringOrNull(data['ownerUsername']);

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: asString(json['id']),
        type: NotificationType.parse(json['type']),
        title: asString(json['title']),
        body: asString(json['body']),
        createdAt: asDate(json['createdAt']),
        isRead: asBool(json['isRead']),
        data: asMap(json['data']),
      );

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    type: type,
    title: title,
    body: body,
    createdAt: createdAt,
    isRead: isRead ?? this.isRead,
    data: data,
  );

  static List<AppNotification> listFrom(Object? value) =>
      asMapList(value).map(AppNotification.fromJson).toList(growable: false);
}

class NotificationPage {
  const NotificationPage({
    required this.notifications,
    required this.total,
    required this.unreadCount,
    required this.page,
    required this.limit,
  });

  final List<AppNotification> notifications;
  final int total;
  final int unreadCount;
  final int page;
  final int limit;

  bool get hasMore => page * limit < total;

  static const empty = NotificationPage(
    notifications: <AppNotification>[],
    total: 0,
    unreadCount: 0,
    page: 1,
    limit: 20,
  );

  factory NotificationPage.fromJson(Map<String, dynamic> json) =>
      NotificationPage(
        notifications: AppNotification.listFrom(json['notifications']),
        total: asInt(json['total']),
        unreadCount: asInt(json['unreadCount']),
        page: asInt(json['page'], fallback: 1),
        limit: asInt(json['limit'], fallback: 20),
      );
}

/// A WhatsApp contact request — the consent gate in front of every phone number.
///
/// Nothing about the owner's number appears here. The number only ever resolves
/// through `/api/profile/[username]/whatsapp`, and only when an `ACCEPTED` row
/// exists for that exact requester/owner pair.
class ContactRequest {
  const ContactRequest({
    required this.id,
    required this.status,
    required this.createdAt,
    this.message,
    this.respondedAt,
    this.counterpartName,
    this.counterpartUsername,
    this.counterpartAvatarUrl,
  });

  final String id;
  final ContactRequestStatus status;
  final DateTime createdAt;
  final String? message;
  final DateTime? respondedAt;
  final String? counterpartName;
  final String? counterpartUsername;
  final String? counterpartAvatarUrl;

  bool get isPending => status == ContactRequestStatus.pending;

  factory ContactRequest.fromJson(Map<String, dynamic> json) {
    // Received requests carry `requester`; sent ones carry `owner`.
    final requester = asMap(json['requester']);
    final owner = asMap(json['owner']);
    final counterpart = requester.isNotEmpty ? requester : owner;
    final media = asMapList(counterpart['media']);

    return ContactRequest(
      id: asString(json['id']),
      status: ContactRequestStatus.parse(json['status']),
      createdAt: asDate(json['createdAt']),
      message: asStringOrNull(json['message']),
      respondedAt: asDateOrNull(json['respondedAt']),
      counterpartName: asStringOrNull(counterpart['displayName']),
      counterpartUsername: asStringOrNull(counterpart['username']),
      counterpartAvatarUrl: media.isEmpty
          ? null
          : asStringOrNull(media.first['storageUrl']),
    );
  }

  static List<ContactRequest> listFrom(Object? value) =>
      asMapList(value).map(ContactRequest.fromJson).toList(growable: false);
}

class ContactRequestInbox {
  const ContactRequestInbox({
    required this.requests,
    required this.pendingCount,
    required this.box,
  });

  final List<ContactRequest> requests;
  final int pendingCount;

  /// `received` or `sent`.
  final String box;

  static const empty = ContactRequestInbox(
    requests: <ContactRequest>[],
    pendingCount: 0,
    box: 'received',
  );

  factory ContactRequestInbox.fromJson(Map<String, dynamic> json) =>
      ContactRequestInbox(
        requests: ContactRequest.listFrom(json['requests']),
        pendingCount: asInt(json['pendingCount']),
        box: asString(json['box'], fallback: 'received'),
      );
}
