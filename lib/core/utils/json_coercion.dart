/// Lenient coercion helpers for JSON fields that may arrive as numbers,
/// strings, or be absent entirely.
int jsonInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? jsonDate(Object? value) {
  if (value == null) {
    return null;
  }
  return DateTime.tryParse(value.toString());
}
