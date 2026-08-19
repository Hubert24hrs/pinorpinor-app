/// Money, in the exact shape the backend stores it.
///
/// **Every rate amount crossing this file is an integer in MINOR units** —
/// kobo, cents — because that is how `dating_profiles.rate*` columns are
/// defined. See the note on those columns in the website's `schema.prisma`:
/// binary floating point cannot represent 0.10 exactly, and a price that
/// drifts by rounding is a price a member and a client argue about.
///
/// **Minor units are not always 1/100.** JPY, KRW, VND, RWF and the XOF/XAF
/// currencies have no minor unit at all, so ¥5000 is stored as `5000`, not
/// `500000`. Dividing by 100 unconditionally would show every Japanese rate
/// at one hundredth of its real value. The `minorDigits` column below is the
/// only thing that knows, and it is transcribed from the website's
/// `src/lib/countries.ts`.
///
/// `null` means "not published" and must render as absent, never as zero. A
/// rate of nothing and an unset rate are very different claims.
library;

/// A currency and how many digits its minor unit has.
class Currency {
  const Currency(this.code, this.symbol, this.minorDigits);

  /// ISO 4217, e.g. `NGN`.
  final String code;

  /// Display symbol, e.g. `₦`.
  final String symbol;

  /// Digits in the minor unit. **Zero for JPY, KRW, VND, RWF, XOF and XAF.**
  final int minorDigits;
}

/// Fallback when a country or code is unknown, matching the website.
const Currency kDefaultCurrency = Currency('USD', r'$', 2);

/// Country code → currency, transcribed from `src/lib/countries.ts`.
const Map<String, Currency> kCurrencies = <String, Currency>{
  'NG': Currency('NGN', r'₦', 2),
  'GH': Currency('GHS', r'GH₵', 2),
  'KE': Currency('KES', r'KSh', 2),
  'ZA': Currency('ZAR', r'R', 2),
  'UG': Currency('UGX', r'USh', 0),
  'TZ': Currency('TZS', r'TSh', 2),
  'ZM': Currency('ZMW', r'ZK', 2),
  'ZW': Currency('ZWL', r'Z$', 2),
  'RW': Currency('RWF', r'FRw', 0),
  'CM': Currency('XAF', r'FCFA', 0),
  'CI': Currency('XOF', r'CFA', 0),
  'SN': Currency('XOF', r'CFA', 0),
  'EG': Currency('EGP', r'E£', 2),
  'MA': Currency('MAD', r'DH', 2),
  'ET': Currency('ETB', r'Br', 2),
  'GB': Currency('GBP', r'£', 2),
  'US': Currency('USD', r'$', 2),
  'CA': Currency('CAD', r'CA$', 2),
  'AU': Currency('AUD', r'A$', 2),
  'NZ': Currency('NZD', r'NZ$', 2),
  'IE': Currency('EUR', r'€', 2),
  'FR': Currency('EUR', r'€', 2),
  'DE': Currency('EUR', r'€', 2),
  'ES': Currency('EUR', r'€', 2),
  'IT': Currency('EUR', r'€', 2),
  'NL': Currency('EUR', r'€', 2),
  'BE': Currency('EUR', r'€', 2),
  'AT': Currency('EUR', r'€', 2),
  'PT': Currency('EUR', r'€', 2),
  'GR': Currency('EUR', r'€', 2),
  'FI': Currency('EUR', r'€', 2),
  'CH': Currency('CHF', r'CHF', 2),
  'SE': Currency('SEK', r'kr', 2),
  'NO': Currency('NOK', r'kr', 2),
  'DK': Currency('DKK', r'kr', 2),
  'PL': Currency('PLN', r'zł', 2),
  'CZ': Currency('CZK', r'Kč', 2),
  'HU': Currency('HUF', r'Ft', 2),
  'RO': Currency('RON', r'lei', 2),
  'UA': Currency('UAH', r'₴', 2),
  'RU': Currency('RUB', r'₽', 2),
  'TR': Currency('TRY', r'₺', 2),
  'AE': Currency('AED', r'AED', 2),
  'SA': Currency('SAR', r'SR', 2),
  'IL': Currency('ILS', r'₪', 2),
  'IN': Currency('INR', r'₹', 2),
  'PK': Currency('PKR', r'Rs', 2),
  'BD': Currency('BDT', r'৳', 2),
  'LK': Currency('LKR', r'Rs', 2),
  'SG': Currency('SGD', r'S$', 2),
  'MY': Currency('MYR', r'RM', 2),
  'ID': Currency('IDR', r'Rp', 2),
  'PH': Currency('PHP', r'₱', 2),
  'TH': Currency('THB', r'฿', 2),
  'VN': Currency('VND', r'₫', 0),
  'CN': Currency('CNY', r'¥', 2),
  'JP': Currency('JPY', r'¥', 0),
  'KR': Currency('KRW', r'₩', 0),
  'BR': Currency('BRL', r'R$', 2),
  'MX': Currency('MXN', r'MX$', 2),
  'AR': Currency('ARS', r'AR$', 2),
  'CL': Currency('CLP', r'CLP$', 0),
  'CO': Currency('COP', r'COL$', 2),
  'PE': Currency('PEN', r'S/', 2),
  'JM': Currency('JMD', r'J$', 2),
  'TT': Currency('TTD', r'TT$', 2),
};

/// The currency for a country code, falling back to [kDefaultCurrency].
Currency currencyForCountry(String? countryCode) {
  if (countryCode == null || countryCode.isEmpty) return kDefaultCurrency;
  return kCurrencies[countryCode.toUpperCase()] ?? kDefaultCurrency;
}

/// The currency for an ISO 4217 code, falling back to [kDefaultCurrency].
Currency currencyByCode(String? code) {
  if (code == null || code.isEmpty) return kDefaultCurrency;
  final String wanted = code.toUpperCase();
  for (final Currency c in kCurrencies.values) {
    if (c.code == wanted) return c;
  }
  return kDefaultCurrency;
}

/// The currency actually in force for a profile: the member's explicit choice,
/// else the one derived from their country. Mirrors `resolveCurrency`.
Currency resolveCurrency({String? storedCurrency, String? countryCode}) {
  if (storedCurrency != null && storedCurrency.isNotEmpty) {
    return currencyByCode(storedCurrency);
  }
  return currencyForCountry(countryCode);
}

/// Groups the integer part with commas: `1234567` → `1,234,567`.
String _groupThousands(String digits) {
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// Formats a stored minor-unit amount for display, or null when unset.
///
/// Returning null rather than an empty string is deliberate: callers must
/// decide whether to omit the row entirely, and a `""` would quietly render as
/// a blank cell that reads like a rate of zero.
///
/// Whole amounts carry no decimals — `₦100,000` reads better than
/// `₦100,000.00`, and these are round numbers in practice. Matches
/// `formatMoney` in `src/lib/countries.ts`.
String? formatMoney(int? minorAmount, {String? currencyCode}) {
  if (minorAmount == null) return null;
  final Currency info = currencyByCode(currencyCode);

  final String sign = minorAmount < 0 ? '-' : '';
  final int abs = minorAmount.abs();

  // No minor unit at all: the stored integer *is* the major amount. Dividing
  // here is what would render ¥5000 as ¥50.
  if (info.minorDigits == 0) {
    return '$sign${info.symbol}${_groupThousands(abs.toString())}';
  }

  final int scale = _pow10(info.minorDigits);
  final String major = _groupThousands((abs ~/ scale).toString());
  final int fraction = abs % scale;

  if (fraction == 0) return '$sign${info.symbol}$major';

  final String frac = fraction.toString().padLeft(info.minorDigits, '0');
  return '$sign${info.symbol}$major.$frac';
}

/// Converts what a member typed (major units) into a storable minor-unit
/// integer. Mirrors `toMinorUnits`.
int toMinorUnits(num majorAmount, {String? currencyCode}) {
  final Currency info = currencyByCode(currencyCode);
  return (majorAmount * _pow10(info.minorDigits)).round();
}

/// Stored minor units back to a major-unit number, for pre-filling an editor.
/// Null in, null out — an unset rate must not become `0`.
num? toMajorUnits(int? minorAmount, {String? currencyCode}) {
  if (minorAmount == null) return null;
  final Currency info = currencyByCode(currencyCode);
  if (info.minorDigits == 0) return minorAmount;
  final int scale = _pow10(info.minorDigits);
  return minorAmount % scale == 0
      ? minorAmount ~/ scale
      : minorAmount / scale;
}

int _pow10(int exponent) {
  int result = 1;
  for (int i = 0; i < exponent; i++) {
    result *= 10;
  }
  return result;
}
