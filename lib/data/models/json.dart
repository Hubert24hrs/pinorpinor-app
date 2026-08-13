/// Defensive readers for API payloads.
///
/// Route handlers omit fields rather than sending nulls in several places, and
/// a couple return different shapes on their error path. Parsing through these
/// helpers means a missing or unexpected value produces an empty model instead
/// of a crash, which is the difference between an empty state and a red screen.
library;

Map<String, dynamic> asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> asMapList(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value.whereType<Map>().map(asMap).toList(growable: false);
}

List<String> asStringList(Object? value) {
  if (value is! List) return const <String>[];
  return value
      .where((element) => element != null)
      .map((element) => element.toString())
      .where((element) => element.isNotEmpty)
      .toList(growable: false);
}

String asString(Object? value, {String fallback = ''}) {
  if (value is String) return value;
  if (value == null) return fallback;
  return value.toString();
}

String? asStringOrNull(Object? value) {
  if (value is String) return value.isEmpty ? null : value;
  if (value == null) return null;
  final text = value.toString();
  return text.isEmpty ? null : text;
}

int asInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

int? asIntOrNull(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? asDoubleOrNull(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

bool asBool(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is String) {
    if (value == 'true') return true;
    if (value == 'false') return false;
  }
  return fallback;
}

/// Prisma serialises `DateTime` as an ISO-8601 string over JSON.
DateTime? asDateOrNull(Object? value) {
  if (value is DateTime) return value;
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}

DateTime asDate(Object? value) => asDateOrNull(value) ?? DateTime.now();
