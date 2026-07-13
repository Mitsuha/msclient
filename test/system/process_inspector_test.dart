import 'package:desktop/system/process_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseCsvRow', () {
    test('splits unquoted columns', () {
      expect(parseCsvRow('a,b,c'), ['a', 'b', 'c']);
    });

    test('keeps commas inside quoted columns', () {
      expect(parseCsvRow('"a,b",c'), ['a,b', 'c']);
    });

    test('unescapes doubled quotes', () {
      expect(parseCsvRow('"say ""hi""",x'), ['say "hi"', 'x']);
    });

    test('parses a tasklist.exe style row', () {
      expect(parseCsvRow('"cc-switch.exe","1234","Console","1","10,000 K"'), [
        'cc-switch.exe',
        '1234',
        'Console',
        '1',
        '10,000 K',
      ]);
    });

    test('returns a single empty column for an empty row', () {
      expect(parseCsvRow(''), ['']);
    });
  });
}
