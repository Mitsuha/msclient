import 'package:desktop/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatMoney renders two decimals with a dollar sign', () {
    expect(formatMoney(128), r'$128.00');
    expect(formatMoney(0.5), r'$0.50');
  });

  test('formatDate renders local zero-padded year-month-day', () {
    final date = DateTime(2026, 7, 2);
    expect(formatDate(date), '2026-07-02');
  });

  group('formatRelativeTime', () {
    final now = DateTime(2026, 7, 20, 12);

    test('collapses anything under a minute — including clock skew', () {
      expect(
        formatRelativeTime(now.subtract(const Duration(seconds: 30)), now: now),
        '刚刚',
      );
      expect(
        formatRelativeTime(now.add(const Duration(hours: 1)), now: now),
        '刚刚',
      );
    });

    test('steps through minutes, hours and days', () {
      expect(
        formatRelativeTime(now.subtract(const Duration(minutes: 5)), now: now),
        '5 分钟前',
      );
      expect(
        formatRelativeTime(now.subtract(const Duration(hours: 3)), now: now),
        '3 小时前',
      );
      expect(
        formatRelativeTime(now.subtract(const Duration(days: 6)), now: now),
        '6 天前',
      );
    });

    test('falls back to an absolute date after a week', () {
      expect(
        formatRelativeTime(now.subtract(const Duration(days: 9)), now: now),
        '2026-07-11',
      );
    });
  });
}
