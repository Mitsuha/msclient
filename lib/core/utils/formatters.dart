/// Display formatters shared across the app.
String formatMoney(num value) {
  return '\$${value.toStringAsFixed(2)}';
}

String formatDate(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

/// Formats a relative time, falling back to a date after seven days.
/// [now] can pin the reference time in tests.
String formatRelativeTime(DateTime value, {DateTime? now}) {
  final elapsed = (now ?? DateTime.now()).difference(value);
  if (elapsed.isNegative || elapsed.inMinutes < 1) {
    return '刚刚';
  }
  if (elapsed.inHours < 1) {
    return '${elapsed.inMinutes} 分钟前';
  }
  if (elapsed.inDays < 1) {
    return '${elapsed.inHours} 小时前';
  }
  if (elapsed.inDays < 7) {
    return '${elapsed.inDays} 天前';
  }
  return formatDate(value);
}
