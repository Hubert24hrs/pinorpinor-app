import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../auth/auth_controller.dart';

/// How often the app tells the backend the member is here.
///
/// Matches `PRESENCE_WRITE_INTERVAL_MS` on the website, which is also the
/// server-side throttle: beating faster would spend requests the server drops on
/// the floor, and beating slower would let a member fall out of the five-minute
/// online window while she is actively using the app.
const Duration kPresenceInterval = Duration(minutes: 2);

/// Beats `POST /api/presence` while the app is in the foreground and signed in.
///
/// The counterpart of `<PresenceHeartbeat/>` in the website's root layout, and
/// it exists for the same reason: `lastSeenAt` is written inside `requireAuth()`
/// and almost nothing a member does hits an authenticated endpoint, so without
/// this a member browsing from the app is invisible on every "who is online"
/// surface — in the app *and* on the website, since both read the same column.
///
/// ## Foreground only, deliberately
///
/// It stops on [AppLifecycleState.paused] and resumes on resume, mirroring the
/// website's "beats only while the tab is visible". A phone in a pocket with the
/// app backgrounded must not report its owner as available; the whole value of
/// the online list is that the people in it are actually there. Nothing is
/// scheduled while the app is not in front, so this costs no battery in the
/// background and needs no permission.
///
/// ## Failures are silent
///
/// A 401 means the session went away, which the app already learns about through
/// [sessionInvalidatedProvider]; anything else is a transient network failure. In
/// both cases the right response is to stop and let the next resume try again —
/// a member should never see an error about a heartbeat.
class PresenceHeartbeat extends ConsumerStatefulWidget {
  const PresenceHeartbeat({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PresenceHeartbeat> createState() => _PresenceHeartbeatState();
}

class _PresenceHeartbeatState extends ConsumerState<PresenceHeartbeat>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _inFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // Beat immediately on resume rather than waiting out the interval: a
        // member who has just opened the app is exactly the case this feature
        // exists to report.
        _sync(beatNow: true);
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _stop();
    }
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _sync({required bool beatNow}) {
    final bool signedIn = ref.read(authControllerProvider).isSignedIn;
    if (!signedIn) {
      _stop();
      return;
    }
    if (beatNow) unawaited(_beat());
    _timer ??= Timer.periodic(kPresenceInterval, (_) => unawaited(_beat()));
  }

  Future<void> _beat() async {
    if (_inFlight) return;
    if (!ref.read(authControllerProvider).isSignedIn) {
      _stop();
      return;
    }
    _inFlight = true;
    try {
      await ref.read(presenceRepositoryProvider).beat();
    } on ApiException {
      // Nothing to tell the member. A rejected session is already handled
      // centrally; anything else is transient and the next beat retries.
    } finally {
      _inFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Signing in starts the heartbeat; signing out stops it. Watching here
    // rather than subscribing in initState means there is exactly one place
    // that decides whether it should be running.
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.isSignedIn) {
        _sync(beatNow: true);
      } else {
        _stop();
      }
    });

    if (ref.watch(authControllerProvider).isSignedIn && _timer == null) {
      // First build after a restored session.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _sync(beatNow: true);
      });
    }

    return widget.child;
  }
}
