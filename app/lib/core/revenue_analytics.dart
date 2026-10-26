import '../data/models.dart';
import 'company_time.dart';
import 'ru_format.dart';

int revenueTotalForMonth(List<Revenue> revenues, DateTime month) {
  final key = monthKey(month);
  return revenues
      .where((revenue) => monthKey(revenue.date) == key)
      .fold(0, (sum, revenue) => sum + revenue.amountKopecks);
}

int revenueTotalForYear(List<Revenue> revenues, DateTime year) {
  return revenues
      .where((revenue) => revenue.date.year == year.year)
      .fold(0, (sum, revenue) => sum + revenue.amountKopecks);
}

int revenueTotalOnDay(List<Revenue> revenues, DateTime day) {
  final key = isoDate(day);
  return revenues
      .where((revenue) => isoDate(revenue.date) == key)
      .fold(0, (sum, revenue) => sum + revenue.amountKopecks);
}

List<int> revenueDailySeries(
  List<Revenue> revenues,
  DateTime today, {
  int days = 30,
}) {
  return List.generate(days, (index) {
    final day = DateTime(
      today.year,
      today.month,
      today.day - (days - 1 - index),
    );
    return revenueTotalOnDay(revenues, day);
  });
}

int? revenueChangePercent(int current, int previous) {
  if (previous == 0) return null;
  return ((current - previous) * 100 / previous).round();
}
