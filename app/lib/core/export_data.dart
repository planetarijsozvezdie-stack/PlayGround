import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../data/models.dart';
import 'ru_format.dart';

class ExportTable {
  const ExportTable({
    required this.sheetName,
    required this.headers,
    required this.rows,
    required this.fileBaseName,
  });

  final String sheetName;
  final List<String> headers;
  final List<List<String>> rows;
  final String fileBaseName;
}

ExportTable institutionsTable(List<Institution> institutions) {
  return ExportTable(
    sheetName: 'Учреждения',
    fileBaseName: 'uchrezhdeniya',
    headers: const [
      'Название',
      'Тип',
      'Номер',
      'Город',
      'Район',
      'Адрес',
      'Контактное лицо',
      'Должность',
      'Телефон',
      'Доп. телефон',
      'Email',
      'Сайт',
      'Статус',
      'Контрагент',
      'Теги',
      'Групп',
      'Вместимость зала',
      'Визитов',
      'Последний визит',
      'Примечания',
      'ID',
    ],
    rows: [
      for (final item in institutions)
        [
          item.name,
          item.type.label,
          item.number,
          item.city,
          item.district,
          item.address,
          item.contactPerson,
          item.position,
          item.phonePrimary,
          item.phoneSecondary,
          item.email,
          item.website,
          item.status.label,
          item.counterparty.label,
          item.tags.join(', '),
          item.groupsCount?.toString() ?? '',
          item.hallCapacity?.toString() ?? '',
          item.totalVisits.toString(),
          _date(item.lastVisitDate),
          item.notes,
          item.id,
        ],
    ],
  );
}

ExportTable revenuesTable(List<Revenue> revenues) {
  return ExportTable(
    sheetName: 'Выручка',
    fileBaseName: 'vyruchka',
    headers: const [
      'Дата',
      'Категория',
      'Контрагент',
      'Сумма, ₽',
      'База налога, ₽',
      'Ставка, %',
      'Вычет, ₽',
      'Налог, ₽',
      'Тип',
      'Комментарий',
      'ID мероприятия',
      'ID',
    ],
    rows: [
      for (final item in revenues)
        [
          _date(item.date),
          item.category == 'session' ? 'Сеанс' : 'Прочее',
          item.counterparty.label,
          _rubles(item.amountKopecks),
          _rubles(item.taxBaseKopecks),
          (item.taxRateBp / 100).toStringAsFixed(0),
          _rubles(item.taxDeductionKopecks),
          _rubles(item.taxAmountKopecks),
          item.amountKopecks < 0
              ? 'Корректировка'
              : item.isReversed
              ? 'Сторнировано'
              : item.isAuto
              ? 'Авто'
              : 'Вручную',
          item.comment,
          item.eventId ?? '',
          item.id,
        ],
    ],
  );
}

String _date(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}.'
      '${local.month.toString().padLeft(2, '0')}.'
      '${local.year}';
}

String _rubles(int kopecks) => (kopecks / 100).toStringAsFixed(2);

Uint8List csvBytes(ExportTable table) {
  final buffer = StringBuffer('\uFEFF');
  buffer.writeln(table.headers.map(_csvCell).join(';'));
  for (final row in table.rows) {
    buffer.writeln(row.map(_csvCell).join(';'));
  }
  return utf8.encode(buffer.toString());
}

String _csvCell(String value) {
  if (value.contains(';') ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

Uint8List xlsxBytes(ExportTable table) {
  final excel = Excel.createExcel();
  const defaultSheet = 'Sheet1';
  if (excel.tables.containsKey(defaultSheet)) {
    excel.rename(defaultSheet, table.sheetName);
  }
  final sheet = excel[table.sheetName];
  sheet.appendRow([for (final header in table.headers) TextCellValue(header)]);
  for (final row in table.rows) {
    sheet.appendRow([for (final value in row) TextCellValue(value)]);
  }
  final bytes = excel.encode();
  if (bytes == null) {
    throw StateError('Не удалось сформировать XLSX');
  }
  return Uint8List.fromList(bytes);
}

String exportFileName(ExportTable table, String extension) {
  final now = DateTime.now();
  final stamp =
      '${now.year}'
      '${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}-'
      '${now.hour.toString().padLeft(2, '0')}'
      '${now.minute.toString().padLeft(2, '0')}';
  return '${table.fileBaseName}-$stamp.$extension';
}

String exportSummary(ExportTable table) =>
    '${table.rows.length} ${pluralRu(table.rows.length, 'запись', 'записи', 'записей')}';
