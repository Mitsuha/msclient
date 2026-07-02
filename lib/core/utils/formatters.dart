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
