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
