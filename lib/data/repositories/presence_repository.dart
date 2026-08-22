import '../../core/network/api_client.dart';

/// The presence heartbeat — `POST /api/presence`.
///
/// ## Why the app has to call this at all
///
/// `users.lastSeenAt` is written inside the backend's `requireAuth()`, so it
/// only moves when a member hits an **authenticated** endpoint. Almost nothing a
/// member does hits one: browsing, discovery and every public profile are
/// unauthenticated reads, in the app exactly as on the website. A signed-in
/// member could use Pinorpinor for an hour and her heartbeat would not move
/// once, so the five-minute "online now" window was very nearly always empty.
///
/// The bug hid because presence never *lied* — it silently under-reported, and
/// an empty "who is online" reads as a quiet night rather than a defect. The
/// website fixed it on 2026-08-20 with this route and a heartbeat in its root
/// layout; without the same call here, every member browsing from the app is
/// invisible on the live surfaces of both clients.
///
/// ## What this deliberately does not send
///
/// **No body, and no timestamp.** None is read. Presence is written server-side
/// from the server clock, and a client-settable "I am online" field is a field
/// people set to lie — here the lie ("she is available right now") is the one
/// with a paying victim.
///
/// The response is 204 with no payload, because the one thing this route must
/// never hand back is a precise last-active time.
class PresenceRepository {
  PresenceRepository(this._api);

  final ApiClient _api;

  /// Records that the member is here now.
  ///
  /// Signed-out callers get 401 and the caller stops asking; there is no such
  /// thing as an anonymous member being online. The throttle lives server-side
  /// (`shouldWritePresence`), so calling more often than necessary costs a
  /// request and nothing else — but see [PresenceHeartbeat] for why the app
  /// paces itself anyway.
  Future<void> beat() async {
    await _api.postJson('/api/presence');
  }
}
