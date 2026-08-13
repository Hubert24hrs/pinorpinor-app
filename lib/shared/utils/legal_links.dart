import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/app_log.dart';

/// Opens the platform's legal and safety pages.
///
/// They open in the system browser rather than an in-app WebView, on purpose.
/// A WebView inside a signed-in app is an easy way to leak a session into
/// content the app does not control, and these pages are static — there is no
/// interaction to keep in-app. The external browser also gives the member the
/// address bar, so they can see they are on pinorpinor.com.
///
/// Only URLs on the app's own origin are ever passed here; the assertion makes
/// that a checkable rule rather than a convention.
class LegalLinks {
  const LegalLinks._();

  static Future<void> open(BuildContext context, String url) async {
    assert(
      url.startsWith(AppConfig.apiOrigin),
      'LegalLinks only opens pages on the Pinorpinor origin.',
    );

    final messenger = ScaffoldMessenger.maybeOf(context);
    final uri = Uri.parse(url);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        messenger?.showSnackBar(
          const SnackBar(content: Text('Could not open that page.')),
        );
      }
    } on Exception catch (error) {
      AppLog.warn('Failed to open legal link: $error');
      messenger?.showSnackBar(
        const SnackBar(content: Text('Could not open that page.')),
      );
    }
  }

  /// Opens an arbitrary external link, used only for the WhatsApp handoff.
  ///
  /// The caller must have obtained the URI from the backend's own redirect —
  /// nothing user-supplied reaches this.
  static Future<bool> openExternal(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Exception catch (error) {
      AppLog.warn('Failed to open external link: $error');
      return false;
    }
  }
}
