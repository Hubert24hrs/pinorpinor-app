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

/// WhatsApp contact requests — the consent gate.
///
/// Nothing here ever carries a phone number. A requester asks, the owner
/// decides, and only an `ACCEPTED` row lets the redirect route resolve a number
/// at all. A declined request is final from the requester's side, so re-asking
/// cannot spam an owner's inbox.
class ContactRepository {
  ContactRepository(this._api);

  final ApiClient _api;

  /// [box] is `received` (requests to me) or `sent` (requests I made).
  Future<ContactRequestInbox> inbox({
    String box = 'received',
    String? status,
  }) async {
    final json = await _api.getJson(
      '/api/contact-requests',
      query: <String, dynamic>{'box': box, 'status': ?status},
    );
    return ContactRequestInbox.fromJson(json);
  }

  /// Asks a profile owner for permission to open a WhatsApp chat.
  ///
  /// Returns the resulting status. An existing request is returned unchanged
  /// rather than re-created, so this is safe to call from a button the member
  /// may tap twice.
  Future<String> requestContact(String username, {String? message}) async {
    final json = await _api.postJson(
      '/api/profile/${Uri.encodeComponent(username.trim().toLowerCase())}/contact-request',
      body: <String, dynamic>{
        if (message != null && message.trim().isNotEmpty)
          'message': message.trim(),
      },
    );
    final status = json['status'];
    return status is String ? status : 'PENDING';
  }

  /// The owner accepts or declines. Only the owner may respond — the requester
  /// cannot move their own request along, and someone else's request id 404s.
  Future<String> respond(String requestId, {required bool accept}) async {
    final json = await _api.patchJson(
      '/api/contact-requests/${Uri.encodeComponent(requestId)}',
      body: <String, String>{'action': accept ? 'accept' : 'decline'},
    );
    final status = json['status'];
    return status is String ? status : (accept ? 'ACCEPTED' : 'DECLINED');
  }
}
