import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planetarium_manager/core/export_data.dart';
import 'package:planetarium_manager/data/seed.dart';

void main() {
  test('CSV учреждений содержит BOM, заголовки и данные', () {
    final bundle = buildSeedBundle();
    final table = institutionsTable(bundle.institutions);
    final bytes = csvBytes(table);
    final text = utf8.decode(bytes);

    expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
    expect(text, contains('Название;Тип;Номер'));
    expect(text, contains(bundle.institutions.first.name));
    expect(table.rows.length, bundle.institutions.length);
  });

  test('XLSX учреждений читается обратно', () {
    final bundle = buildSeedBundle();
    final table = institutionsTable(bundle.institutions);
    final bytes = xlsxBytes(table);
    final decoded = Excel.decodeBytes(bytes);
    final sheet = decoded.tables[table.sheetName]!;

    expect(sheet.maxRows, bundle.institutions.length + 1);
    expect(sheet.rows.first.first?.value, TextCellValue('Название'));
    expect(
      sheet.rows[1][1]?.value,
      TextCellValue(bundle.institutions.first.type.label),
    );
  });

  test('CSV выручки экранирует разделитель и кавычки', () {
    final table = ExportTable(
      sheetName: 'Выручка',
      fileBaseName: 'vyruchka',
      headers: const ['Комментарий'],
      rows: const [
        ['Счёт; акт "№1"'],
      ],
    );

    expect(utf8.decode(csvBytes(table)), contains('"Счёт; акт ""№1"""'));
  });
}
