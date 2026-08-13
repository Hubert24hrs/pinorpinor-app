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
