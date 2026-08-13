import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the NextAuth session cookie in platform-backed secure storage.
///
/// The website authenticates with NextAuth's credentials provider, which issues
/// an `HttpOnly`, `Secure` JWT cookie. Reproducing that on mobile means holding
/// one cookie, so this stores exactly that — never in `SharedPreferences`, never
/// in a plain file, never logged.
///
/// On Android this is the EncryptedSharedPreferences backend (Keystore-wrapped);
/// on iOS it is the Keychain with `first_unlock_this_device` accessibility, so a
/// device backup restored onto different hardware cannot carry the session with
/// it.
class SessionStore {
  SessionStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // Android: EncryptedSharedPreferences is the only backend from
            // plugin v10 onwards, so there is no flag to set — the keys are
            // Keystore-wrapped either way.
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  final FlutterSecureStorage _storage;

  static const _cookieKey = 'pnp.session.cookies';

  /// NextAuth's cookie names. The `__Secure-`/`__Host-` prefixed forms are what
  /// production issues over HTTPS; the bare names appear on plain-HTTP local
  /// development, so both are recognised.
  static const sessionCookieNames = <String>[
    '__Secure-next-auth.session-token',
    'next-auth.session-token',
  ];

  static const csrfCookieNames = <String>[
    '__Host-next-auth.csrf-token',
    'next-auth.csrf-token',
  ];

  Map<String, String>? _cache;

  /// All cookies currently held, keyed by cookie name.
  Future<Map<String, String>> readAll() async {
    final cached = _cache;
    if (cached != null) return cached;

    final raw = await _storage.read(key: _cookieKey);
    if (raw == null || raw.isEmpty) return _cache = <String, String>{};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return _cache = <String, String>{};
      return _cache = decoded.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } on FormatException {
      // A corrupted blob is treated as "signed out" rather than crashing the
      // app on launch. The user re-authenticates; nothing else is lost.
      await clear();
      return _cache = <String, String>{};
    }
  }

  Future<void> writeAll(Map<String, String> cookies) async {
    _cache = Map<String, String>.from(cookies);
    await _storage.write(key: _cookieKey, value: jsonEncode(cookies));
  }

  /// Merges freshly received cookies over the stored set. An empty value means
  /// the server cleared that cookie (sign-out), so the entry is dropped.
  Future<void> merge(Map<String, String> incoming) async {
    if (incoming.isEmpty) return;
    final current = Map<String, String>.from(await readAll());
    incoming.forEach((name, value) {
      if (value.isEmpty) {
        current.remove(name);
      } else {
        current[name] = value;
      }
    });
    await writeAll(current);
  }

  Future<String?> readSessionToken() async {
    final cookies = await readAll();
    for (final name in sessionCookieNames) {
      final value = cookies[name];
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  Future<bool> get hasSession async => (await readSessionToken()) != null;

  /// Builds the `Cookie:` header value for an outgoing request.
  Future<String?> cookieHeader() async {
    final cookies = await readAll();
    if (cookies.isEmpty) return null;
    return cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  Future<void> clear() async {
    _cache = <String, String>{};
    await _storage.delete(key: _cookieKey);
  }
}
