import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../utils/app_log.dart';
import 'deep_links.dart';

/// Listens for inbound deep links and routes them.
///
/// Wrapped around the app so the cold-start link and every later link go
/// through the same resolver. [DeepLinks.resolve] returns null for anything the
/// app does not claim, and that null is ignored — an unrecognised link never
/// opens a browser, never becomes an action, and never leaves the app's own
/// route table.
class DeepLinkHandler extends StatefulWidget {
  const DeepLinkHandler({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  State<DeepLinkHandler> createState() => _DeepLinkHandlerState();
}

class _DeepLinkHandlerState extends State<DeepLinkHandler> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      // The link that launched the app, if any.
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _handle(initial);
    } on Exception catch (error) {
      AppLog.warn('Initial deep link failed: $error');
    }

    _subscription = _appLinks.uriLinkStream.listen(
      _handle,
      onError: (Object error) => AppLog.warn('Deep link stream error: $error'),
    );
  }

  void _handle(Uri uri) {
    final destination = DeepLinks.resolve(uri);
    if (destination == null) {
      AppLog.debug('Ignoring unrecognised deep link');
      return;
    }
    // `go` rather than `push`: a link should land on the destination, not stack
    // it on top of whatever the member was doing.
    widget.router.go(destination);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
