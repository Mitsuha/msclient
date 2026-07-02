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
}
