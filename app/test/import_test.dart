import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:planetarium_manager/core/export_data.dart';
import 'package:planetarium_manager/core/import_data.dart';
import 'package:planetarium_manager/data/models.dart';
import 'package:planetarium_manager/data/seed.dart';

void main() {
  test('CSV с BOM, ; и кавычками разбирается в таблицу', () {
    final csv =
        '\uFEFFНазвание;Тип;Город;Номер\n'
        '"Сад; №1";Детский сад;Уфа;1\n'
        '"Школа ""Плюс""";Школа;Уфа;2\n';
    final table = parseCsvBytes(Uint8List.fromList(utf8.encode(csv)));

    expect(table.headers, ['Название', 'Тип', 'Город', 'Номер']);
    expect(table.rows.length, 2);
    expect(table.rows.first.first, 'Сад; №1');
    expect(table.rows.last.first, 'Школа "Плюс"');
  });

  test('автоматическое сопоставление и разбор учреждений', () {
    final table = parseDelimited(
      'Наименование;Тип;№;Город;Телефон\n'
      'Сад №1;детский сад;1;Уфа;+7 999\n'
      ';школа;2;Уфа;\n',
    );
    final mapping = guessInstitutionMapping(table.headers);
    final result = parseInstitutions(table, mapping);

    expect(mapping['name'], 0);
    expect(mapping['phone_primary'], 4);
    expect(result.drafts.length, 1);
    expect(result.drafts.first.type, InstitutionType.kindergarten);
    expect(result.errors.single, contains('Строка 3'));
  });

  test('XLSX, созданный экспортом, читается импортом', () {
    final bundle = buildSeedBundle();
    final export = institutionsTable(bundle.institutions);
    final table = parseXlsxBytes(xlsxBytes(export));
    final result = parseInstitutions(
      table,
      guessInstitutionMapping(table.headers),
    );

    expect(result.errors, isEmpty);
    expect(result.drafts.length, bundle.institutions.length);
    expect(result.drafts.first.name, bundle.institutions.first.name);
  });

  test('ключ дубликата нормализует номер и город', () {
    expect(
      institutionDedupeKey(
        type: InstitutionType.school,
        number: '№ 5',
        city: 'Нижний Новгород',
      ),
      institutionDedupeKey(
        type: InstitutionType.school,
        number: '5',
        city: 'нижний-новгород',
      ),
    );
  });
}
