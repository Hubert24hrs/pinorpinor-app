import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/credits.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';

/// Opening a WhatsApp chat, which is now the one thing credits buy.
///
/// ## What replaced what
///
/// Until 2026-08-23 this was a **consent** flow: the viewer asked, the member
/// accepted or declined, and an ACCEPTED `ContactRequest` unlocked the number.
/// The website removed those routes entirely and replaced them with a price.
/// `/api/contact-requests` and `/api/profile/[username]/contact-request` no
/// longer exist, so every call this app made to them was a 404 — see
/// `docs/` and CLAUDE.md for the drift this is part of.
///
/// ## Both sides pay, all or nothing
///
/// Opening a chat costs the sender [kWhatsAppUnlockCredits] **and the member
/// being contacted the same amount**, in one transaction. If either wallet
/// cannot cover it, neither is charged and no chat opens.
///
/// That is the owner's decision, and it has two consequences the app must state
/// rather than let a member discover:
///
///   * a member whose balance falls below the price becomes **unreachable**, and
///   * members lose credits **passively**, by being contacted.
///
/// ## Three answers, and they mean different things
///
/// * **402 `INSUFFICIENT_CREDITS`** — the *viewer* is short. The response names
///   the price and their own balance, because that is something they can act on.
/// * **409 `TARGET_CANNOT_RECEIVE`** — the *other side* cannot cover their half.
///   Reported without a balance and without blame: the viewer did nothing wrong,
///   is owed an explanation rather than an accusation, and has no business
///   learning what is in somebody else's wallet. **Never re-word this into
///   "they have no credits".**
/// * **404** — unreachable, which the backend uses for "no such profile",
///   "hidden", "opted out" and "no number on file" alike, so a caller cannot
///   probe which profiles have a number. Do not try to interpret it further.
///
/// A second visit to somebody already paid for is free forever, and staff are
/// never charged; both come back as an ordinary redirect with no debit.
class ContactAccessRepository {
  ContactAccessRepository(this._api);

  final ApiClient _api;

  /// What one chat costs each side. A constant rather than a fetch: it is the
  /// same figure the server charges, and a screen that has to await a round trip
  /// before it can label a button ends up labelling it wrongly for a moment.
  int get price => kWhatsAppUnlockCredits;

  /// Pays for and resolves the `wa.me` link for a member.
  ///
  /// **This spends credits.** It must only ever be called from a control that
  /// has told the member the price first — see [ContactAccessFailure] for the
  /// states a caller has to render.
  ///
  /// The redirect is read rather than followed: following it would fetch
  /// WhatsApp's page over the app's own client for no purpose, and the
  /// `Location` header is the actual payload.
  Future<Uri> openChat(String username) async {
    final String normalized = username.trim().toLowerCase();
    try {
      final Response<dynamic> response = await _api.raw.get<dynamic>(
        '/api/profile/${Uri.encodeComponent(normalized)}/whatsapp',
        options: Options(
          followRedirects: false,
          validateStatus: (int? status) => status != null && status < 400,
          // Both wallets are debited inside one transaction the server gives 60
          // seconds. Timing out under that would tell a member the unlock
          // failed after they had already paid for it.
          receiveTimeout: AppConfig.slowTransactionTimeout,
        ),
      );

      final String? location = response.headers.value('location');
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
      throw _asFailure(error);
    }
  }

  /// Maps the two paid-contact refusals onto something a screen can render,
  /// and leaves everything else as an ordinary [ApiException].
  ///
  /// The server's own `code` is used rather than the status alone, so a future
  /// 402 for some other reason does not silently render as "top up".
  ApiException _asFailure(DioException error) {
    final Object? data = error.response?.data;
    final Map<String, dynamic> body = data is Map<String, dynamic>
        ? data
        : <String, dynamic>{};
    final Object? code = body['code'];

    if (code == 'INSUFFICIENT_CREDITS') {
      return ContactAccessFailure(
        reason: ContactAccessRefusal.viewerShort,
        message:
            body['error']?.toString() ??
            'You need $kWhatsAppUnlockCredits credits to message this member.',
        price: body['price'] is int
            ? body['price']! as int
            : kWhatsAppUnlockCredits,
        balance: body['balance'] is int ? body['balance']! as int : null,
      );
    }

    if (code == 'TARGET_CANNOT_RECEIVE') {
      return ContactAccessFailure(
        reason: ContactAccessRefusal.targetCannotReceive,
        // Deliberately the server's wording, which names no balance and blames
        // nobody.
        message:
            body['error']?.toString() ??
            'This member cannot receive messages at the moment.',
        price: kWhatsAppUnlockCredits,
      );
    }

    return ApiException.fromDio(error);
  }

  /// Turns a `wa.me` link into the native app scheme, keeping the prefilled
  /// text.
  ///
  /// `whatsapp://send` opens the installed app directly; the original `https`
  /// link is the fallback for a device without WhatsApp, where it opens the web
  /// client instead of failing.
  static Uri toAppScheme(Uri waMeLink) {
    final String phone = waMeLink.pathSegments.isEmpty
        ? ''
        : waMeLink.pathSegments.last;
    final String text = waMeLink.queryParameters['text'] ?? '';
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

/// Which side of a paid contact fell short.
enum ContactAccessRefusal {
  /// The viewer cannot cover the price. Actionable: they can top up.
  viewerShort,

  /// The member being contacted cannot cover their half. **Not** actionable by
  /// the viewer, and not their fault.
  targetCannotReceive,
}

/// A refusal a contact button has to render as a state rather than an error.
class ContactAccessFailure extends ApiException {
  const ContactAccessFailure({
    required this.reason,
    required super.message,
    required this.price,
    this.balance,
  }) : super(
         kind: ApiErrorKind.validation,
         code: reason == ContactAccessRefusal.viewerShort
             ? 'INSUFFICIENT_CREDITS'
             : 'TARGET_CANNOT_RECEIVE',
       );

  final ContactAccessRefusal reason;

  /// What one chat costs each side.
  final int price;

  /// The **viewer's** balance, and only ever theirs. Null for
  /// [ContactAccessRefusal.targetCannotReceive], because the other member's
  /// balance is not the viewer's business.
  final int? balance;

  /// How many more credits the viewer needs, when that is knowable.
  int? get shortfall => balance == null ? null : price - balance!;
}
