import 'package:desktop/system/env_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseEnvLines', () {
    test('parses KEY=value pairs', () {
      expect(parseEnvLines(['a=1', 'b=2']), {'a': '1', 'b': '2'});
    });

    test('skips comments, blank lines, and lines without =', () {
      expect(parseEnvLines(['# comment', '', 'not-a-pair', 'a=1']), {'a': '1'});
    });

    test('trims whitespace and strips matching quotes', () {
      expect(
        parseEnvLines(['  a =  "quoted"  ', "b='single'", 'c="unbalanced']),
        {'a': 'quoted', 'b': 'single', 'c': '"unbalanced'},
      );
    });

    test('keeps = characters inside the value', () {
      expect(parseEnvLines(['a=b=c']), {'a': 'b=c'});
    });

    test('last duplicate key wins', () {
      expect(parseEnvLines(['a=1', 'a=2']), {'a': '2'});
    });
  });

  group('serializeEnv', () {
    test('joins entries with newlines and ends with one', () {
      expect(serializeEnv({'a': '1', 'b': '2'}), 'a=1\nb=2\n');
    });

    test('round-trips through parseEnvLines', () {
      final values = {'http_proxy': 'https://proxy:5211', 'x': 'y'};
      expect(parseEnvLines(serializeEnv(values).split('\n')), values);
    });
  });
}
