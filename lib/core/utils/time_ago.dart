import 'package:intl/intl.dart';

/// Compact relative time for lists: "now", "4m", "3h", "2d", then a date.
///
/// Kept short because it sits at the end of a row that must not wrap on a
/// 320px-wide phone.
String timeAgo(DateTime value, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final delta = reference.difference(value);

  if (delta.isNegative) return 'now';
  if (delta.inMinutes < 1) return 'now';
  if (delta.inMinutes < 60) return '${delta.inMinutes}m';
  if (delta.inHours < 24) return '${delta.inHours}h';
  if (delta.inDays < 7) return '${delta.inDays}d';
  if (value.year == reference.year) return DateFormat('d MMM').format(value);
  return DateFormat('d MMM yyyy').format(value);
}

/// Long form, for a message bubble's timestamp and profile metadata.
String formatDateTime(DateTime value) =>
    DateFormat('d MMM yyyy · HH:mm').format(value);

String formatTime(DateTime value) => DateFormat('HH:mm').format(value);

String formatDate(DateTime value) => DateFormat('d MMMM yyyy').format(value);

/// Day separator inside a conversation.
String messageDayLabel(DateTime value, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final today = DateTime(reference.year, reference.month, reference.day);
  final day = DateTime(value.year, value.month, value.day);
  final difference = today.difference(day).inDays;

  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  if (difference < 7) return DateFormat('EEEE').format(value);
  return DateFormat('d MMMM yyyy').format(value);
}

/// "in 3 hours" / "in 2 days", used for boost expiry.
String timeUntil(DateTime value, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final delta = value.difference(reference);
  if (delta.isNegative) return 'expired';
  if (delta.inMinutes < 60) return 'in ${delta.inMinutes} min';
  if (delta.inHours < 24) {
    return 'in ${delta.inHours} ${delta.inHours == 1 ? 'hour' : 'hours'}';
  }
  return 'in ${delta.inDays} ${delta.inDays == 1 ? 'day' : 'days'}';
}
