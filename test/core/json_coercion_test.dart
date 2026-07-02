import 'package:desktop/core/utils/json_coercion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('jsonInt', () {
    test('passes ints through', () {
      expect(jsonInt(7), 7);
    });

    test('truncates doubles', () {
      expect(jsonInt(7.9), 7);
    });

    test('parses numeric strings', () {
      expect(jsonInt('42'), 42);
    });

    test('falls back to 0 for null or garbage', () {
      expect(jsonInt(null), 0);
      expect(jsonInt('abc'), 0);
    });
  });

  group('jsonDate', () {
    test('parses ISO-8601 strings', () {
      expect(jsonDate('2026-07-02T10:00:00Z'), DateTime.utc(2026, 7, 2, 10));
    });

    test('returns null for null or unparsable input', () {
      expect(jsonDate(null), isNull);
      expect(jsonDate('not a date'), isNull);
    });
  });
}
