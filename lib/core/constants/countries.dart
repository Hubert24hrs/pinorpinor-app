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
