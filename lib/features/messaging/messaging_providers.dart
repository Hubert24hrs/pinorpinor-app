import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../data/models/messaging.dart';
import '../auth/auth_controller.dart';
import '../notifications/notification_providers.dart';

final conversationsProvider =
    FutureProvider.autoDispose<List<ConversationSummary>>((ref) async {
      return ref.watch(messagingRepositoryProvider).conversations();
    });

final matchesProvider = FutureProvider.autoDispose<List<MatchSummary>>((
  ref,
) async {
  return ref.watch(discoveryRepositoryProvider).matches();
});

/// A single thread: its history, its pending sends and its polling.
@immutable
class ThreadState {
  const ThreadState({
    this.messages = const <Message>[],
    this.isLoading = true,
    this.isLoadingOlder = false,
    this.hasMore = false,
    this.error,
    this.sendError,
  });

  final List<Message> messages;
  final bool isLoading;
  final bool isLoadingOlder;
  final bool hasMore;
  final Object? error;
  final String? sendError;

  ThreadState copyWith({
    List<Message>? messages,
    bool? isLoading,
    bool? isLoadingOlder,
    bool? hasMore,
    Object? error,
    String? sendError,
    bool clearError = false,
    bool clearSendError = false,
  }) => ThreadState(
    messages: messages ?? this.messages,
    isLoading: isLoading ?? this.isLoading,
    isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
    hasMore: hasMore ?? this.hasMore,
    error: clearError ? null : (error ?? this.error),
    sendError: clearSendError ? null : (sendError ?? this.sendError),
  );
}

/// Drives one conversation.
///
/// **Delivery model.** The backend has no realtime channel — no websocket, no
/// Supabase Realtime subscription (the data API is closed), no SSE. New messages
/// therefore arrive by polling while the thread is open. The interval is short
/// enough to feel live and the request is a single indexed query, and it stops
/// the moment the screen is disposed.
///
/// Sends are optimistic: the message renders immediately with `isPending`, then
/// is replaced by the server's row. A failure marks it failed rather than
/// silently dropping it, so the member can retry the exact text.
class ThreadNotifier extends StateNotifier<ThreadState> {
  ThreadNotifier(this._ref, this._conversationId) : super(const ThreadState()) {
    unawaited(load());
    _poll = Timer.periodic(
      const Duration(seconds: 12),
      (_) => unawaited(_pollNew()),
    );
  }

  final Ref _ref;
  final String _conversationId;
  Timer? _poll;
  String? _oldestCursor;
  bool _polling = false;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final page = await _ref
          .read(messagingRepositoryProvider)
          .messages(_conversationId);
      if (!mounted) return;
      _oldestCursor = page.nextCursor;
      state = ThreadState(
        messages: page.messages,
        isLoading: false,
        hasMore: page.hasMore,
      );
      // Fetching history also clears the thread's unread state server-side
      // (the route updates `lastReadAt`), so refresh the badge rather than
      // leaving a count that no longer reflects the database.
      unawaited(_ref.read(unreadBadgeProvider.notifier).refresh());
    } on ApiException catch (error) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: error);
    }
  }

  Future<void> loadOlder() async {
    final cursor = _oldestCursor;
    if (cursor == null || state.isLoadingOlder) return;

    state = state.copyWith(isLoadingOlder: true);
    try {
      final page = await _ref
          .read(messagingRepositoryProvider)
          .messages(_conversationId, cursor: cursor);
      if (!mounted) return;
      _oldestCursor = page.nextCursor;
      state = state.copyWith(
        messages: <Message>[...page.messages, ...state.messages],
        isLoadingOlder: false,
        hasMore: page.hasMore,
      );
    } on ApiException {
      if (mounted) state = state.copyWith(isLoadingOlder: false);
    }
  }

  Future<void> _pollNew() async {
    if (_polling || state.isLoading) return;
    _polling = true;
    try {
      final page = await _ref
          .read(messagingRepositoryProvider)
          .messages(_conversationId);
      if (!mounted) return;

      final known = state.messages.map((m) => m.id).toSet();
      final incoming = page.messages
          .where((m) => !known.contains(m.id))
          .toList();
      if (incoming.isEmpty) return;

      // Keep any still-pending local echoes at the end so a slow send is not
      // visually swallowed by a poll that landed first.
      final pending = state.messages.where((m) => m.isPending).toList();
      final settled = state.messages.where((m) => !m.isPending).toList();

      state = state.copyWith(
        messages: <Message>[...settled, ...incoming, ...pending],
      );
    } on ApiException {
      // Silent: a dropped poll just means the next one catches up.
    } finally {
      _polling = false;
    }
  }

  Future<void> send(String text) async {
    final content = text.trim();
    if (content.isEmpty) return;

    final me = _ref.read(authControllerProvider).userId ?? '';
    final localId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final echo = Message(
      id: localId,
      senderId: me,
      createdAt: DateTime.now(),
      content: content,
      isPending: true,
    );

    state = state.copyWith(
      messages: <Message>[...state.messages, echo],
      clearSendError: true,
    );

    try {
      final sent = await _ref
          .read(messagingRepositoryProvider)
          .send(_conversationId, content: content);
      if (!mounted) return;
      state = state.copyWith(
        messages: <Message>[
          for (final message in state.messages)
            if (message.id == localId) sent else message,
        ],
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      state = state.copyWith(
        messages: <Message>[
          for (final message in state.messages)
            if (message.id == localId)
              message.copyWith(isPending: false, failed: true)
            else
              message,
        ],
        sendError: error.message,
      );
    }
  }

  /// Drops a failed echo and re-sends its text.
  Future<void> retry(Message failed) async {
    state = state.copyWith(
      messages: state.messages.where((m) => m.id != failed.id).toList(),
    );
    await send(failed.content ?? '');
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }
}

final threadProvider = StateNotifierProvider.autoDispose
    .family<ThreadNotifier, ThreadState, String>(
      (ref, conversationId) => ThreadNotifier(ref, conversationId),
    );
