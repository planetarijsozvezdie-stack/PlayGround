import 'package:flutter_test/flutter_test.dart';
import 'package:planetarium_manager/core/revenue_analytics.dart';
import 'package:planetarium_manager/core/tax.dart';
import 'package:planetarium_manager/data/models.dart';

Revenue revenue(DateTime date, int amount) {
  return Revenue(
    id: 'r-${date.millisecondsSinceEpoch}-$amount',
    companyId: 'c1',
    eventId: null,
    date: date,
    amountKopecks: amount,
    grossKopecks: amount,
    category: 'event',
    counterparty: CounterpartyType.legal,
    taxRateBp: 600,
    taxBaseKopecks: amount,
    taxDeductionKopecks: 0,
    taxAmountKopecks: 0,
    isAuto: false,
    isReversed: amount < 0,
    reversalOfId: null,
    comment: '',
  );
}

void main() {
  test('суммы за месяц, год и день учитывают сторно', () {
    final revenues = [
      revenue(DateTime(2026, 10, 26), 100000),
      revenue(DateTime(2026, 10, 1), 50000),
      revenue(DateTime(2026, 9, 30), 70000),
      revenue(DateTime(2026, 10, 26), -20000),
      revenue(DateTime(2025, 12, 31), 30000),
    ];

    expect(revenueTotalForMonth(revenues, DateTime(2026, 10)), 130000);
    expect(revenueTotalForYear(revenues, DateTime(2026)), 200000);
    expect(revenueTotalOnDay(revenues, DateTime(2026, 10, 26)), 80000);
  });

  test('30-дневный ряд заканчивается сегодняшним днём', () {
    final today = DateTime(2026, 10, 26);
    final series = revenueDailySeries([
      revenue(today, 10000),
      revenue(DateTime(2026, 10, 25), 4000),
      revenue(DateTime(2026, 9, 26), 9999),
    ], today);

    expect(series, hasLength(30));
    expect(series.last, 10000);
    expect(series[28], 4000);
    expect(series.first, 0);
  });

  test('процент изменения считается к прошлому периоду', () {
    expect(revenueChangePercent(150000, 100000), 50);
    expect(revenueChangePercent(80000, 100000), -20);
    expect(revenueChangePercent(0, 0), isNull);
    expect(revenueChangePercent(50000, 0), isNull);
  });
}
