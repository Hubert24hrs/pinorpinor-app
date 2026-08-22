/// The country list the backend accepts, transcribed from `src/lib/countries.ts`.
///
/// `code` is the stored value (`dating_profiles.countryCode`) and the only thing
/// discovery scopes on; `name` is display-only. Registration rejects anything
/// outside this list, so the picker must not offer more than the server allows.
library;

class Country {
  const Country(this.code, this.name);

  final String code;
  final String name;
}

const List<Country> kCountries = <Country>[
  Country('AR', 'Argentina'),
  Country('AU', 'Australia'),
  Country('AT', 'Austria'),
  Country('BD', 'Bangladesh'),
  Country('BE', 'Belgium'),
  Country('BR', 'Brazil'),
  Country('CM', 'Cameroon'),
  Country('CA', 'Canada'),
  Country('CL', 'Chile'),
  Country('CN', 'China'),
  Country('CO', 'Colombia'),
  Country('CI', "Côte d'Ivoire"),
  Country('CZ', 'Czechia'),
  Country('DK', 'Denmark'),
  Country('EG', 'Egypt'),
  Country('ET', 'Ethiopia'),
  Country('FI', 'Finland'),
  Country('FR', 'France'),
  Country('DE', 'Germany'),
  Country('GH', 'Ghana'),
  Country('GR', 'Greece'),
  Country('HU', 'Hungary'),
  Country('IN', 'India'),
  Country('ID', 'Indonesia'),
  Country('IE', 'Ireland'),
  Country('IL', 'Israel'),
  Country('IT', 'Italy'),
  Country('JM', 'Jamaica'),
  Country('JP', 'Japan'),
  Country('KE', 'Kenya'),
  Country('MY', 'Malaysia'),
  Country('MX', 'Mexico'),
  Country('MA', 'Morocco'),
  Country('NL', 'Netherlands'),
  Country('NZ', 'New Zealand'),
  Country('NG', 'Nigeria'),
  Country('NO', 'Norway'),
  Country('PK', 'Pakistan'),
  Country('PE', 'Peru'),
  Country('PH', 'Philippines'),
  Country('PL', 'Poland'),
  Country('PT', 'Portugal'),
  Country('RO', 'Romania'),
  Country('RU', 'Russia'),
  Country('RW', 'Rwanda'),
  Country('SA', 'Saudi Arabia'),
  Country('SN', 'Senegal'),
  Country('SG', 'Singapore'),
  Country('ZA', 'South Africa'),
  Country('KR', 'South Korea'),
  Country('ES', 'Spain'),
  Country('SE', 'Sweden'),
  Country('CH', 'Switzerland'),
  Country('TZ', 'Tanzania'),
  Country('TH', 'Thailand'),
  Country('TT', 'Trinidad and Tobago'),
  Country('TR', 'Türkiye'),
  Country('UG', 'Uganda'),
  Country('UA', 'Ukraine'),
  Country('AE', 'United Arab Emirates'),
  Country('GB', 'United Kingdom'),
  Country('US', 'United States'),
  Country('VN', 'Vietnam'),
  Country('ZM', 'Zambia'),
  Country('ZW', 'Zimbabwe'),
];

/// Nigeria — the platform's home market, offered first in the picker.
const String kDefaultCountryCode = 'NG';

String? countryNameFor(String? code) {
  if (code == null || code.isEmpty) return null;
  final upper = code.toUpperCase();
  for (final country in kCountries) {
    if (country.code == upper) return country.name;
  }
  return null;
}

/// Accepts a code or a display name, as the backend's `normalizeCountry` does —
/// legacy rows stored free-text names.
String? normalizeCountryCode(String? input) {
  if (input == null) return null;
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;
  final upper = trimmed.toUpperCase();
  for (final country in kCountries) {
    if (country.code == upper) return country.code;
  }
  final lower = trimmed.toLowerCase();
  for (final country in kCountries) {
    if (country.name.toLowerCase() == lower) return country.code;
  }
  return null;
}

/// The date-activity options the website's join form offers.
const List<String> kDateTypeOptions = <String>[
  'Dinner Dates',
  'Coffee & Chats',
  'Movie Nights',
  'Live Music',
  'VIP Events',
  'Beach Days',
  'Travel Companion',
  'Nightlife',
  'Art & Culture',
  'Fitness & Outdoors',
];

/// Dialling code to country, mirroring `DIAL_CODES` in `src/lib/countries.ts`.
///
/// The backend derives a new member's country from their WhatsApp number with
/// this table, and **discovery scopes on the result** — so a number that does
/// not resolve leaves the member listed nowhere until they set a location in
/// Edit Profile. The app carries a copy for one reason only: to show the right
/// currency beside the rate fields while a member is typing, before any account
/// exists to read a country from. It is never sent, and the server's answer is
/// the one that counts.
///
/// Order matters. Longest prefix wins: `+1` is the US, but `+1868` is Trinidad
/// and must be tested first — which is what [countryFromPhone] does rather than
/// relying on this list's order.
const List<({String dial, String code})> kDialCodes =
    <({String dial, String code})>[
      (dial: '+1868', code: 'TT'),
      (dial: '+1876', code: 'JM'),
      (dial: '+20', code: 'EG'),
      (dial: '+212', code: 'MA'),
      (dial: '+225', code: 'CI'),
      (dial: '+221', code: 'SN'),
      (dial: '+234', code: 'NG'),
      (dial: '+233', code: 'GH'),
      (dial: '+237', code: 'CM'),
      (dial: '+250', code: 'RW'),
      (dial: '+251', code: 'ET'),
      (dial: '+254', code: 'KE'),
      (dial: '+255', code: 'TZ'),
      (dial: '+256', code: 'UG'),
      (dial: '+260', code: 'ZM'),
      (dial: '+263', code: 'ZW'),
      (dial: '+27', code: 'ZA'),
      (dial: '+30', code: 'GR'),
      (dial: '+31', code: 'NL'),
      (dial: '+32', code: 'BE'),
      (dial: '+33', code: 'FR'),
      (dial: '+34', code: 'ES'),
      (dial: '+351', code: 'PT'),
      (dial: '+353', code: 'IE'),
      (dial: '+358', code: 'FI'),
      (dial: '+36', code: 'HU'),
      (dial: '+39', code: 'IT'),
      (dial: '+40', code: 'RO'),
      (dial: '+41', code: 'CH'),
      (dial: '+43', code: 'AT'),
      (dial: '+44', code: 'GB'),
      (dial: '+45', code: 'DK'),
      (dial: '+46', code: 'SE'),
      (dial: '+47', code: 'NO'),
      (dial: '+48', code: 'PL'),
      (dial: '+49', code: 'DE'),
      (dial: '+51', code: 'PE'),
      (dial: '+52', code: 'MX'),
      (dial: '+54', code: 'AR'),
      (dial: '+55', code: 'BR'),
      (dial: '+56', code: 'CL'),
      (dial: '+57', code: 'CO'),
      (dial: '+60', code: 'MY'),
      (dial: '+62', code: 'ID'),
      (dial: '+63', code: 'PH'),
      (dial: '+64', code: 'NZ'),
      (dial: '+65', code: 'SG'),
      (dial: '+66', code: 'TH'),
      (dial: '+7', code: 'RU'),
      (dial: '+81', code: 'JP'),
      (dial: '+82', code: 'KR'),
      (dial: '+84', code: 'VN'),
      (dial: '+86', code: 'CN'),
      (dial: '+880', code: 'BD'),
      (dial: '+90', code: 'TR'),
      (dial: '+91', code: 'IN'),
      (dial: '+92', code: 'PK'),
      (dial: '+966', code: 'SA'),
      (dial: '+971', code: 'AE'),
      (dial: '+972', code: 'IL'),
      (dial: '+380', code: 'UA'),
      (dial: '+61', code: 'AU'),
      (dial: '+1', code: 'US'),
    ];

/// Best-effort country for an E.164 number, mirroring `countryFromPhone`.
///
/// Returns null for anything unrecognised. **Callers must handle that rather
/// than defaulting to a country the member never chose** — the server does the
/// same, and a guess here would put a price in the wrong currency.
String? countryFromPhone(String? phone) {
  final String trimmed = (phone ?? '').trim();
  if (trimmed.isEmpty) return null;

  final List<({String dial, String code})> byLength =
      <({String dial, String code})>[...kDialCodes]
        ..sort((a, b) => b.dial.length.compareTo(a.dial.length));

  for (final entry in byLength) {
    if (trimmed.startsWith(entry.dial)) return entry.code;
  }
  return null;
}
