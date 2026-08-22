import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/credits.dart';
import '../models/json.dart';

/// Credits and profile boosts.
///
/// **Payments.** Card payment on the platform is switched off:
/// `PAYSTACK_ENABLED` defaults false and `/api/credits/payments/init` answers
/// `503`. Credits are sold over WhatsApp and applied by an administrator, with
/// every movement written to an append-only ledger. The app reproduces that
/// exactly and deliberately ships **no** in-app purchase path:
///
///   * There is no client-side "payment succeeded" flag anywhere. Balance is
///     read from the server, and boosts are activated by the server debiting the
///     wallet inside a transaction.
///   * Because the app never sells the credits, it never has to route a digital
///     purchase through Google Play Billing or StoreKit. Adding a card checkout
///     to the app *would* trigger those rules — see `docs/STORE_READINESS.md`
///     for the full reasoning before anyone re-enables Paystack here.
///
/// [initCardPayment] exists so the conflict is documented in code rather than
/// discovered later, and it refuses to run rather than opening a checkout.
class CreditsRepository {
  CreditsRepository(this._api);

  final ApiClient _api;

  Future<Wallet> wallet() async =>
      Wallet.fromJson(await _api.getJson('/api/credits/wallet'));

  Future<List<CreditPackage>> packages() async {
    final json = await _api.getJson('/api/credits/packages');
    return CreditPackage.listFrom(json['packages']);
  }

  Future<List<BoostTier>> boostTiers() async {
    final json = await _api.getJson('/api/credits/boost-tiers');
    return BoostTier.listFrom(json['tiers']);
  }

  Future<List<LedgerEntry>> ledger({int page = 1, int limit = 25}) async {
    final json = await _api.getJson(
      '/api/credits/wallet/ledger',
      query: <String, dynamic>{'page': page, 'limit': limit},
    );
    // The route has gone through more than one response shape; accept both
    // rather than rendering an empty history if it changes again.
    final rows = json.containsKey('entries') ? json['entries'] : json['ledger'];
    return LedgerEntry.listFrom(rows);
  }

  /// Spends credits on a boost. The debit, the ledger entry and the profile
  /// flags all move in one server-side transaction; a 402 means the wallet was
  /// short, and nothing was charged.
  Future<BoostResult> activateBoost(int tier) async {
    final json = await _api.postJson(
      '/api/credits/boost',
      body: <String, dynamic>{'tier': tier},
    );
    final boost = asMap(json['boost']);
    return BoostResult(
      balance: asInt(json['balance']),
      tier: asInt(boost['tier']),
      expiresAt: asDateOrNull(boost['expiresAt']),
    );
  }

  /// The member's referral code, link and results.
  ///
  /// The 500-credit payout has always worked; every part of it a member could
  /// see was missing until the website shipped this endpoint on 2026-08-21.
  /// Nothing here identifies who signed up — see [ReferralSummary].
  Future<ReferralSummary> referrals() async =>
      ReferralSummary.fromJson(await _api.getJson('/api/referrals'));

  /// Card checkout is intentionally unavailable from the app.
  ///
  /// Kept as a named, throwing method so the decision is visible where a future
  /// contributor would look for it, instead of being an absence they might
  /// "fix" by wiring up a WebView checkout — which is precisely what both app
  /// stores' payment rules prohibit for digital goods.
  Future<Never> initCardPayment(String packageId) {
    throw const ApiException(
      kind: ApiErrorKind.unavailable,
      message: 'Card payments are unavailable. Buy credits on WhatsApp.',
    );
  }
}

class BoostResult {
  const BoostResult({
    required this.balance,
    required this.tier,
    this.expiresAt,
  });

  final int balance;
  final int tier;
  final DateTime? expiresAt;
}
