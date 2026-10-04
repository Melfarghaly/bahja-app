import 'package:intl/intl.dart';

/// Times are shown in the device's local time (Egyptian devices = Cairo).
String formatTime(DateTime? value, [String locale = 'ar']) =>
    value == null ? '—' : DateFormat.Hm(locale).format(value.toLocal());

String formatDate(DateTime? value, [String locale = 'ar']) =>
    value == null ? '—' : DateFormat.yMMMd(locale).format(value.toLocal());

String formatDateTime(DateTime? value, [String locale = 'ar']) => value == null
    ? '—'
    : DateFormat.MMMd(locale).add_Hm().format(value.toLocal());

/// "منذ ٥ دقائق" style relative time for feeds.
String relativeTime(DateTime value, [String locale = 'ar']) {
  final diff = DateTime.now().difference(value);
  final ar = locale == 'ar';
  if (diff.inMinutes < 1) return ar ? 'الآن' : 'now';
  if (diff.inMinutes < 60) {
    return ar ? 'منذ ${diff.inMinutes} د' : '${diff.inMinutes}m ago';
  }
  if (diff.inHours < 24) {
    return ar ? 'منذ ${diff.inHours} س' : '${diff.inHours}h ago';
  }
  return formatDateTime(value, locale);
}

String isoDate(DateTime value) => DateFormat('yyyy-MM-dd').format(value);
