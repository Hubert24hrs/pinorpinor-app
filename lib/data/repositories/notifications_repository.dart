import '../../core/network/api_client.dart';
import '../models/notifications.dart';

class NotificationsRepository {
  NotificationsRepository(this._api);

  final ApiClient _api;

  Future<NotificationPage> list({int page = 1, int limit = 20}) async {
    final json = await _api.getJson(
      '/api/notifications',
      query: <String, dynamic>{'page': page, 'limit': limit},
    );
    return NotificationPage.fromJson(json);
  }

  /// Marks one notification read, or all of them when [notificationId] is null.
  /// The update is scoped to the caller's own rows server-side.
  Future<void> markRead({String? notificationId}) async {
    await _api.patchJson(
      '/api/notifications',
      body: <String, dynamic>{'notificationId': ?notificationId},
    );
  }
}
