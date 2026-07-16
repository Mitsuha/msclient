import 'package:desktop/ui/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the bundled HarmonyOS font on Windows', () {
    final theme = buildAppTheme(isWindows: true);

    expect(theme.textTheme.textStyle.fontFamily, windowsFontFamily);
  });

  test('keeps the system font on non-Windows platforms', () {
    final theme = buildAppTheme(isWindows: false);

    expect(theme.textTheme.textStyle.fontFamily, isNull);
  });
}
