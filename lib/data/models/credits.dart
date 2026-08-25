import 'json.dart';

/// The member's credit wallet, from `GET /api/credits/wallet`.
///
/// Credits pay for profile boosts. They are **sold over WhatsApp and applied by
/// an admin** — card payments are switched off on the backend
/// (`PAYSTACK_ENABLED=false`, the payment routes answer 503). See
/// `docs/STORE_READINESS.md` for why that arrangement is also the one the app
/// stores accept.
class Wallet {
  const Wallet({
    required this.balance,
    this.whatsappNumber,
    this.referralCode,
    this.referralCount = 0,
    this.boostActive = false,
    this.boostTier = 0,
    this.boostExpiresAt,
    this.featuredActive = false,
    this.featuredUntil,
  });

  final int balance;

  /// The platform's own sales number, served by the backend. Never a member's.
  final String? whatsappNumber;

  final String? referralCode;
  final int referralCount;
  final bool boostActive;
  final int boostTier;
  final DateTime? boostExpiresAt;
  final bool featuredActive;
  final DateTime? featuredUntil;

  static const empty = Wallet(balance: 0);

  factory Wallet.fromJson(Map<String, dynamic> json) {
    final boost = asMap(json['boost']);
    final featured = asMap(json['featured']);
    final referral = asMap(json['referral']);
    return Wallet(
      balance: asInt(json['balance']),
      whatsappNumber: asStringOrNull(json['whatsappNumber']),
      referralCode: asStringOrNull(referral['code']),
      referralCount: asInt(referral['count']),
      boostActive: asBool(boost['active']),
      boostTier: asInt(boost['tier']),
      boostExpiresAt: asDateOrNull(boost['expiresAt']),
      featuredActive: asBool(featured['active']),
      featuredUntil: asDateOrNull(featured['until']),
    );
  }
}

class BoostTier {
  const BoostTier({
    required this.tier,
    required this.name,
    required this.costCredits,
    required this.durationHours,
    this.description,
  });

  final int tier;
  final String name;
  final int costCredits;
  final int durationHours;
  final String? description;

  factory BoostTier.fromJson(Map<String, dynamic> json) => BoostTier(
    tier: asInt(json['tier']),
    name: asString(json['name'], fallback: 'Boost'),
    costCredits: asInt(json['costCredits']),
    durationHours: asInt(json['durationHours']),
    description: asStringOrNull(json['description']),
  );

  static List<BoostTier> listFrom(Object? value) =>
      asMapList(value).map(BoostTier.fromJson).toList(growable: false);
}

/// A purchasable bundle. Prices are in kobo, the smallest NGN unit, exactly as
/// the `credit_packages` table stores them.
class CreditPackage {
  const CreditPackage({
    required this.id,
    required this.name,
    required this.credits,
    required this.priceKobo,
    this.bonusCredits = 0,
    this.currency = 'NGN',
  });

  final String id;
  final String name;
  final int credits;
  final int bonusCredits;
  final int priceKobo;
  final String currency;

  int get totalCredits => credits + bonusCredits;

  /// Naira, to two places. Only ever used for display.
  String get priceLabel {
    final major = priceKobo / 100;
    final symbol = currency == 'NGN' ? '₦' : '$currency ';
    return '$symbol${major.toStringAsFixed(major.truncateToDouble() == major ? 0 : 2)}';
  }

  factory CreditPackage.fromJson(Map<String, dynamic> json) => CreditPackage(
    id: asString(json['id']),
    name: asString(json['name']),
    credits: asInt(json['credits']),
    bonusCredits: asInt(json['bonusCredits']),
    priceKobo: asInt(json['priceKobo']),
    currency: asString(json['currency'], fallback: 'NGN'),
  );

  static List<CreditPackage> listFrom(Object? value) =>
      asMapList(value).map(CreditPackage.fromJson).toList(growable: false);
}

class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.amount,
    required this.balanceAfter,
    required this.reason,
    required this.createdAt,
    this.note,
  });

  final String id;
  final int amount;
  final int balanceAfter;
  final String reason;
  final DateTime createdAt;
  final String? note;

  bool get isCredit => amount > 0;

  String get reasonLabel => switch (reason) {
    'PURCHASE' => 'Credits purchased',
    'BOOST_PURCHASE' => 'Boost activated',
    'ADMIN_ADJUSTMENT' => 'Adjustment',
    'REFUND' => 'Refund',
    'SIGNUP_BONUS' => 'Welcome bonus',
    'REFERRAL_BONUS' => 'Referral bonus',
    _ => 'Activity',
  };

  factory LedgerEntry.fromJson(Map<String, dynamic> json) => LedgerEntry(
    id: asString(json['id']),
    amount: asInt(json['amount']),
    balanceAfter: asInt(json['balanceAfter']),
    reason: asString(json['reason']),
    createdAt: asDate(json['createdAt']),
    note: asStringOrNull(json['note']),
  );

  static List<LedgerEntry> listFrom(Object? value) =>
      asMapList(value).map(LedgerEntry.fromJson).toList(growable: false);
}

/// The caller's own referral code, link and results, from `GET /api/referrals`.
///
/// ## What this deliberately does not carry
///
/// **No usernames, no display names, no join dates** for the people who signed
/// up — only a count and a credit total, because that is all the endpoint
/// returns. A referral list is a record of "this person knows that person", and
/// on an adult platform that is exactly the join nobody consented to: someone
/// who used a friend's link has not agreed to be shown back to that friend as a
/// trophy. The count answers the only question the panel exists to answer, which
/// is whether the link is working.
///
/// [creditsEarned] is summed from the ledger server-side, never
/// `referrals * creditsPerReferral`: that would silently re-price everyone's
/// history the first time the bonus changes.
class ReferralSummary {
  const ReferralSummary({
    this.referralCode,
    this.referralUrl,
    this.referrals = 0,
    this.creditsEarned = 0,
    this.creditsPerReferral = 0,
  });

  static const empty = ReferralSummary();

  final String? referralCode;

  /// Built server-side from the real site origin, so a link copied here still
  /// works when pasted somewhere permanent.
  final String? referralUrl;

  final int referrals;
  final int creditsEarned;
  final int creditsPerReferral;

  bool get hasCode => (referralCode ?? '').isNotEmpty;

  factory ReferralSummary.fromJson(Map<String, dynamic> json) =>
      ReferralSummary(
        referralCode: asStringOrNull(json['referralCode']),
        referralUrl: asStringOrNull(json['referralUrl']),
        referrals: asInt(json['referrals']),
        creditsEarned: asInt(json['creditsEarned']),
        creditsPerReferral: asInt(json['creditsPerReferral']),
      );
}

/// A recorded request to buy credits, from `/api/credits/purchase`.
///
/// ## Why a record exists at all
///
/// Card payment is off, so credits are sold over WhatsApp and applied by hand.
/// That conversation used to leave no trace: a member messaged the business
/// number, an admin adjusted a wallet from memory, and nothing recorded what was
/// agreed — reconciling a disputed top-up meant scrolling a chat thread.
///
/// The request is now written down **before** the chat opens, and the message
/// the member sends carries the same reference the admin queue shows. The app
/// never moves credits: this is a statement of intent, and treating it as
/// anything more would let anyone credit themselves by tapping a button.
class CreditPurchase {
  const CreditPurchase({
    required this.id,
    required this.reference,
    required this.credits,
    required this.amountNaira,
    required this.status,
    this.createdAt,
    this.approvedAt,
  });

  final String id;

  /// Short, human-readable, and deliberately drawn from an alphabet with no
  /// O/0 or I/1 — it gets read aloud and retyped off a phone screen.
  final String reference;

  final int credits;

  /// Whole Naira, not minor units. Credits are not money and this figure is
  /// display only; the admin confirms what actually arrived.
  final int amountNaira;

  /// `PENDING`, `APPROVED` or `REJECTED` as the server spells them.
  final String status;

  final DateTime? createdAt;
  final DateTime? approvedAt;

  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED';

  String get statusLabel => switch (status) {
    'PENDING' => 'Waiting for confirmation',
    'APPROVED' => 'Credits added',
    'REJECTED' => 'Not completed',
    _ => status,
  };

  factory CreditPurchase.fromJson(Map<String, dynamic> json) => CreditPurchase(
    id: asString(json['id']),
    reference: asString(json['reference']),
    credits: asInt(json['credits']),
    amountNaira: asInt(json['amountNaira']),
    status: asString(json['status'], fallback: 'PENDING'),
    createdAt: asDateOrNull(json['createdAt']),
    approvedAt: asDateOrNull(json['approvedAt']),
  );

  static List<CreditPurchase> listFrom(Object? value) =>
      asMapList(value).map(CreditPurchase.fromJson).toList(growable: false);
}

/// The answer to a top-up request: the row, and the message to send.
class CreditPurchaseResult {
  const CreditPurchaseResult({required this.purchase, this.whatsappUrl});

  final CreditPurchase purchase;

  /// Built server-side so the message, the stored row and the admin queue can
  /// never disagree about what was asked for. **Never rebuild it here.**
  final String? whatsappUrl;

  factory CreditPurchaseResult.fromJson(Map<String, dynamic> json) =>
      CreditPurchaseResult(
        purchase: CreditPurchase.fromJson(asMap(json['purchase'])),
        whatsappUrl: asStringOrNull(json['whatsappUrl']),
      );
}
