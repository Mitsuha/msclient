import 'package:desktop/system/app_updater.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isNewerVersion', () {
    test('recognizes a higher version', () {
      expect(isNewerVersion('1.0.2', '1.0.1'), isTrue);
      expect(isNewerVersion('2.0.0', '1.99.99'), isTrue);
    });

    test('rejects equal and older versions', () {
      expect(isNewerVersion('1.0.1', '1.0.1'), isFalse);
      expect(isNewerVersion('1.0.0', '1.0.1'), isFalse);
      expect(isNewerVersion('1.0', '1.0.0'), isFalse);
    });

    test('compares build numbers', () {
      expect(isNewerVersion('1.0.2+8', '1.0.1+9'), isTrue);
      expect(isNewerVersion('1.0.1+10', '1.0.1+9'), isTrue);
      expect(isNewerVersion('1.0.1+8', '1.0.1+9'), isFalse);
    });
  });
}
