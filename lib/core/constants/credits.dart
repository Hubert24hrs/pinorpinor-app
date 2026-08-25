/// What credits cost, and what they buy.
///
/// **Mirrors the website's `src/lib/credits.ts` and `src/lib/credit-purchase.ts`.**
/// Every one of these is a public figure a member is shown before they spend
/// anything, so none of it is secret — but all of it must match the server,
/// because the server is what actually charges.
///
/// ## Credits are not money, twice over
///
/// A credit is an integer. [kNairaPerCredit] converts one to Naira **for
/// display only**; the app never computes a charge. Do not route these through
/// `formatMoney`, which works in minor units — 100 credits is ₦1,000, not ₦1.
///
/// They are also not the same thing as the per-minute prices in
/// `live_sessions.dart`, which are credits a member *charges*, nor the booking
/// rates in `rates.dart`, which are real currency the platform never touches.
library;

/// Naira per credit. Display only — the amount owed is computed server-side and
/// carried in the WhatsApp message the purchase route builds.
const int kNairaPerCredit = 10;

/// What opening a WhatsApp chat costs, **each side**.
///
/// Since 2026-08-23 the sender pays this and the member being contacted pays it
/// too, in one transaction: if either wallet cannot cover it, neither is charged
/// and no chat opens. That is the owner's decision and it has two consequences
/// the app has to state plainly rather than let a member discover:
///
///   * a member who runs out of credits becomes **unreachable**, and
///   * members lose credits **passively**, by being contacted.
///
/// Both are intended. They are what makes a balance something a member has to
/// maintain, and a member who is not told will read the first one as a bug.
const int kWhatsAppUnlockCredits = 100;

/// Steps offered on the top-up screen, matching `CREDIT_PURCHASE_PRESETS`.
const List<int> kCreditPurchasePresets = <int>[100, 200, 300, 500, 1000, 2000];

/// The smallest and largest top-up the route will quote for.
const int kMinCreditPurchase = 100;
const int kMaxCreditPurchase = 100000;

/// Credits are sold in multiples of this. A request for 150 is refused rather
/// than rounded, because rounding somebody's money without telling them is
/// worse than making them retype it.
const int kCreditDenomination = 100;

/// The Naira figure for a credit amount. Display only.
int nairaForCredits(int credits) => credits * kNairaPerCredit;

/// Validates a typed top-up amount, mirroring `quoteCreditPurchase`.
///
/// Returns the server's own refusal, or null when the amount is quotable.
String? creditPurchaseError(Object? input) {
  final int? credits = input is int
      ? input
      : int.tryParse(
          (input?.toString() ?? '').replaceAll(RegExp(r'[\s,]'), ''),
        );

  // Order matters, and it is the route's order: the denomination check runs
  // before the floor so somebody typing 50 is told about multiples rather than
  // about the minimum, which is the more useful of the two answers.
  if (credits == null || credits <= 0) {
    return 'Choose how many credits you want to buy.';
  }
  if (credits % kCreditDenomination != 0) {
    final int nearest =
        ((credits / kCreditDenomination).round() * kCreditDenomination).clamp(
          kCreditDenomination,
          kMaxCreditPurchase,
        );
    return 'Credits are sold in ${kCreditDenomination}s. Try $nearest.';
  }
  if (credits < kMinCreditPurchase) {
    return 'The smallest top up is $kMinCreditPurchase credits.';
  }
  if (credits > kMaxCreditPurchase) {
    return 'The largest single top up is 100,000 credits. Ask for that much '
        'and then ask again.';
  }
  return null;
}
