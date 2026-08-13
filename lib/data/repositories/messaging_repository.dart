import '../../core/network/api_client.dart';
import '../models/json.dart';
import '../models/messaging.dart';

class MessagingRepository {
  MessagingRepository(this._api);

  final ApiClient _api;

  Future<List<ConversationSummary>> conversations() async {
    final json = await _api.getJson('/api/conversations');
    return ConversationSummary.listFrom(json['conversations']);
  }

  /// One page of history, newest last.
  ///
  /// The backend pages backwards with a cursor and reverses before responding,
  /// so `messages` always arrives in reading order and `nextCursor` walks
  /// further into the past.
  ///
  /// Note that fetching a page also marks the thread read server-side — the
  /// route updates `lastReadAt` as a side effect, so there is no separate
  /// "mark read" call to make.
  Future<MessagePage> messages(
    String conversationId, {
    String? cursor,
    int limit = 30,
  }) async {
    final json = await _api.getJson(
      '/api/conversations/${Uri.encodeComponent(conversationId)}/messages',
      query: <String, dynamic>{'limit': limit, 'cursor': ?cursor},
    );
    return MessagePage.fromJson(json);
  }

  /// Sends a message. Refused with 403 once either side has unmatched.
  Future<Message> send(
    String conversationId, {
    String? content,
    String? mediaUrl,
  }) async {
    final json = await _api.postJson(
      '/api/conversations/${Uri.encodeComponent(conversationId)}/messages',
      body: <String, dynamic>{
        if (content != null && content.trim().isNotEmpty)
          'content': content.trim(),
        if (mediaUrl != null && mediaUrl.isNotEmpty) 'mediaUrl': mediaUrl,
      },
    );
    return Message.fromJson(asMap(json['message']));
  }
}
