import 'package:intl/intl.dart';

int roundHalfUpDiv(int numerator, int denominator) {
  assert(numerator >= 0, 'numerator must be non-negative');
  assert(denominator > 0, 'denominator must be positive');
  return (numerator * 2 + denominator) ~/ (denominator * 2);
}

final NumberFormat _moneyFormat = NumberFormat('#,##0.00', 'ru_RU');
final NumberFormat _wholeFormat = NumberFormat('#,##0', 'ru_RU');

String formatKopecks(int kopecks) => '${_moneyFormat.format(kopecks / 100)} ₽';

String formatRubles(int kopecks) => '${_wholeFormat.format(kopecks ~/ 100)} ₽';

String formatPercentBp(int basisPoints) {
  final value = basisPoints / 100;
  final digits = basisPoints % 100 == 0 ? 0 : 2;
  return '${value.toStringAsFixed(digits)}%';
}

int rubToKopecks(num rubles) => (rubles * 100).round();

String formatAmount(int kopecks) => _moneyFormat.format(kopecks / 100);
