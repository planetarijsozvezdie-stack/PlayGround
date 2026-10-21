import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

Future<void> ensureRussianLocale() => initializeDateFormatting('ru_RU');

String formatDateRu(DateTime date) =>
    DateFormat('d MMMM y', 'ru_RU').format(date);

String formatDateShortRu(DateTime date) =>
    DateFormat('d MMM', 'ru_RU').format(date);

String formatMonthYearRu(DateTime date) =>
    DateFormat('LLLL y', 'ru_RU').format(date);

const _weekdaysShort = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

String formatWeekdayShortRu(DateTime date) => _weekdaysShort[date.weekday - 1];

String formatTimeRange(String timeStart, int durationMinutes) {
  final parts = timeStart.split(':');
  final start = DateTime(2000, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
  final end = start.add(Duration(minutes: durationMinutes));
  final f = DateFormat('HH:mm');
  return '${f.format(start)}–${f.format(end)}';
}

String pluralRu(int count, String one, String few, String many) {
  final mod100 = count.abs() % 100;
  final mod10 = count.abs() % 10;
  if (mod100 >= 11 && mod100 <= 14) return many;
  if (mod10 == 1) return one;
  if (mod10 >= 2 && mod10 <= 4) return few;
  return many;
}

String childrenCountLabel(int count) =>
    '$count ${pluralRu(count, 'ребёнок', 'ребёнка', 'детей')}';

String programsCountLabel(int count) =>
    '$count ${pluralRu(count, 'программа', 'программы', 'программ')}';

String sessionsCountLabel(int count) =>
    '$count ${pluralRu(count, 'сеанс', 'сеанса', 'сеансов')}';

String documentsCountLabel(int count) =>
    '$count ${pluralRu(count, 'документ', 'документа', 'документов')}';

String isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

DateTime dateFromIso(String value) {
  final parts = value.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}
