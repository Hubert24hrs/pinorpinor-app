import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';

/// The WhatsApp handoff.
///
/// **What the platform actually has:** click-to-chat only. There is no WhatsApp
/// Business or Cloud API anywhere in the backend — no templates, no webhooks, no
/// message sending. One route, `/api/profile/[username]/whatsapp`, looks a
/// member's number up server-side and answers with a `307` to `wa.me`. The
/// number is never in any JSON body, page payload or DOM, and the app never
/// receives it as data either.
///
/// Three gates stand in front of that redirect, all server-enforced:
///   1. the caller must be signed in (an open endpoint would let anyone
///      enumerate usernames and harvest numbers from `Location` headers),
///   2. the caller's account must not be suspended,
///   3. an **ACCEPTED** `ContactRequest` must exist for that exact
///      requester/owner pair.
///
/// So this class does not "integrate WhatsApp" — it follows one redirect and
/// hands the resulting link to the system. That is the whole feature, and
/// reproducing it faithfully matters more than making it look bigger.
class WhatsAppRepository {
  WhatsAppRepository(this._api);

  final ApiClient _api;

  /// Resolves the `wa.me` link for a member, or throws with the server's own
  /// message.
  ///
  /// The redirect is read rather than followed: following it would fetch
  /// WhatsApp's web page over the app's own client for no purpose, and the
  /// `Location` header is the actual payload.
  ///
  /// A 403 means no accepted contact request. A 404 means unreachable — and the
  /// backend deliberately uses that same 404 for "no such profile", "hidden",
  /// "opted out" and "no number on file", so a caller cannot probe which
  /// profiles have a number. The app must not try to interpret it further.
  Future<Uri> resolveChatLink(String username) async {
    final normalized = username.trim().toLowerCase();
    try {
      final response = await _api.raw.get<dynamic>(
        '/api/profile/${Uri.encodeComponent(normalized)}/whatsapp',
        options: Options(
          followRedirects: false,
          validateStatus: (status) => status != null && status < 400,
        ),
      );

      final location = response.headers.value('location');
      if (location == null || location.isEmpty) {
        throw const ApiException(
          kind: ApiErrorKind.notFound,
          message: 'This member is not reachable on WhatsApp.',
        );
      }

      // A signed-out caller is redirected to /login instead. Treat that as
      // "sign in first" rather than opening a browser at the login page.
      if (location.contains('/login')) {
        throw const ApiException(
          kind: ApiErrorKind.unauthorized,
          message: 'Please sign in to contact members.',
        );
      }

      return Uri.parse(location);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// Turns a `wa.me` link into the native app scheme, keeping the prefilled text.
  ///
  /// `whatsapp://send` opens the installed app directly; the original `https`
  /// link is the fallback for a device without WhatsApp, where it opens the web
  /// client instead of failing.
  static Uri toAppScheme(Uri waMeLink) {
    final phone = waMeLink.pathSegments.isEmpty
        ? ''
        : waMeLink.pathSegments.last;
    final text = waMeLink.queryParameters['text'] ?? '';
    return Uri(
      scheme: 'whatsapp',
      host: 'send',
      queryParameters: <String, String>{
        if (phone.isNotEmpty) 'phone': phone,
        if (text.isNotEmpty) 'text': text,
      },
    );
  }
}
