import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../data/models.dart';
import 'tax.dart';

class ImportTable {
  const ImportTable({required this.headers, required this.rows});

  final List<String> headers;
  final List<List<String>> rows;
}

class InstitutionDraft {
  const InstitutionDraft({
    required this.name,
    required this.type,
    required this.number,
    required this.city,
    required this.district,
    required this.address,
    required this.contactPerson,
    required this.phonePrimary,
    required this.email,
    required this.notes,
    required this.status,
    required this.counterparty,
    required this.tags,
  });

  final String name;
  final InstitutionType type;
  final String number;
  final String city;
  final String district;
  final String address;
  final String contactPerson;
  final String phonePrimary;
  final String email;
  final String notes;
  final InstitutionStatus status;
  final CounterpartyType counterparty;
  final List<String> tags;

  String get dedupeKey =>
      institutionDedupeKey(type: type, number: number, city: city);
}

class ImportParseResult {
  const ImportParseResult({required this.drafts, required this.errors});

  final List<InstitutionDraft> drafts;
  final List<String> errors;
}

class ImportField {
  const ImportField(this.key, this.label);

  final String key;
  final String label;
}

const institutionImportFields = [
  ImportField('name', 'Название'),
  ImportField('type', 'Тип'),
  ImportField('number', 'Номер'),
  ImportField('city', 'Город'),
  ImportField('district', 'Район'),
  ImportField('address', 'Адрес'),
  ImportField('contact_person', 'Контактное лицо'),
  ImportField('phone_primary', 'Телефон'),
  ImportField('email', 'Email'),
  ImportField('status', 'Статус'),
  ImportField('counterparty', 'Контрагент'),
  ImportField('tags', 'Теги'),
  ImportField('notes', 'Примечания'),
];

const _aliases = <String, List<String>>{
  'name': ['название', 'наименование', 'учреждение', 'name'],
  'type': ['тип', 'типу', 'type'],
  'number': ['номер', '№', 'number'],
  'city': ['город', 'city'],
  'district': ['район', 'district'],
  'address': ['адрес', 'address'],
  'contact_person': [
    'контактное лицо',
    'контакт',
    'фио',
    'contact',
    'contactperson',
  ],
  'phone_primary': ['телефон', 'phone', 'phoneprimary', 'тел'],
  'email': ['email', 'почта', 'электронная почта'],
  'status': ['статус', 'status'],
  'counterparty': ['контрагент', 'counterparty'],
  'tags': ['теги', 'tags'],
  'notes': ['примечания', 'заметки', 'notes'],
};

Map<String, int> guessInstitutionMapping(List<String> headers) {
  final result = <String, int>{};
  for (var index = 0; index < headers.length; index++) {
    final header = normalizeImportText(headers[index]);
    for (final field in institutionImportFields) {
      if (result.containsKey(field.key)) continue;
      final aliases = _aliases[field.key] ?? const <String>[];
      if (aliases.any((alias) => normalizeImportText(alias) == header)) {
        result[field.key] = index;
        break;
      }
    }
  }
  return result;
}

ImportParseResult parseInstitutions(
  ImportTable table,
  Map<String, int> mapping,
) {
  final drafts = <InstitutionDraft>[];
  final errors = <String>[];
  for (var index = 0; index < table.rows.length; index++) {
    final row = table.rows[index];
    final line = index + 2;
    final name = _cell(row, mapping['name']).trim();
    final city = _cell(row, mapping['city']).trim();
    if (name.isEmpty) {
      errors.add('Строка $line: не заполнено название');
      continue;
    }
    if (city.isEmpty) {
      errors.add('Строка $line: не заполнен город');
      continue;
    }
    drafts.add(
      InstitutionDraft(
        name: name,
        type: _type(_cell(row, mapping['type'])),
        number: _cell(row, mapping['number']).trim(),
        city: city,
        district: _cell(row, mapping['district']).trim(),
        address: _cell(row, mapping['address']).trim(),
        contactPerson: _cell(row, mapping['contact_person']).trim(),
        phonePrimary: _cell(row, mapping['phone_primary']).trim(),
        email: _cell(row, mapping['email']).trim(),
        notes: _cell(row, mapping['notes']).trim(),
        status: _status(_cell(row, mapping['status'])),
        counterparty: _counterparty(_cell(row, mapping['counterparty'])),
        tags: _tags(_cell(row, mapping['tags'])),
      ),
    );
  }
  return ImportParseResult(drafts: drafts, errors: errors);
}

String institutionDedupeKey({
  required InstitutionType type,
  required String number,
  required String city,
}) {
  final normalizedNumber = normalizeImportText(number);
  if (normalizedNumber.isEmpty) return '';
  return '${type.name}|$normalizedNumber|${normalizeImportText(city)}';
}

String normalizeImportText(String value) => value
    .toLowerCase()
    .replaceAll('ё', 'е')
    .replaceAll(RegExp(r'[^0-9a-zа-я]+'), '');

ImportTable parseCsvBytes(Uint8List bytes) =>
    parseDelimited(utf8.decode(bytes, allowMalformed: true));

ImportTable parseDelimited(String input) {
  var text = input;
  if (text.startsWith('\uFEFF')) text = text.substring(1);
  if (text.trim().isEmpty) {
    return const ImportTable(headers: [], rows: []);
  }
  final firstLine = text.split(RegExp(r'\r?\n')).first;
  final delimiter = _detectDelimiter(firstLine);
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var index = 0; index < text.length; index++) {
    final char = text[index];
    if (quoted) {
      if (char == '"') {
        if (index + 1 < text.length && text[index + 1] == '"') {
          cell.write('"');
          index++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(char);
      }
      continue;
    }
    if (char == '"') {
      quoted = true;
    } else if (char == delimiter) {
      row.add(cell.toString());
      cell.clear();
    } else if (char == '\n') {
      row.add(cell.toString());
      cell.clear();
      rows.add(row);
      row = <String>[];
    } else if (char != '\r') {
      cell.write(char);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    rows.add(row);
  }
  rows.removeWhere((item) => item.every((value) => value.trim().isEmpty));
  if (rows.isEmpty) {
    return const ImportTable(headers: [], rows: []);
  }
  return ImportTable(
    headers: rows.first.map((value) => value.trim()).toList(),
    rows: rows.skip(1).toList(),
  );
}

String _detectDelimiter(String line) {
  final semicolons = ';'.allMatches(line).length;
  final commas = ','.allMatches(line).length;
  final tabs = '\t'.allMatches(line).length;
  if (tabs > semicolons && tabs > commas) return '\t';
  return semicolons >= commas ? ';' : ',';
}

ImportTable parseXlsxBytes(Uint8List bytes) {
  final excel = Excel.decodeBytes(bytes);
  if (excel.tables.isEmpty) {
    return const ImportTable(headers: [], rows: []);
  }
  final sheet = excel.tables.values.first;
  final rows = <List<String>>[];
  for (final row in sheet.rows) {
    final values = row.map(_cellText).toList();
    if (values.every((value) => value.trim().isEmpty)) continue;
    rows.add(values);
  }
  if (rows.isEmpty) {
    return const ImportTable(headers: [], rows: []);
  }
  return ImportTable(
    headers: rows.first.map((value) => value.trim()).toList(),
    rows: rows.skip(1).toList(),
  );
}

String _cellText(Data? cell) {
  final value = cell?.value;
  return switch (value) {
    null => '',
    TextCellValue() => value.value.toString(),
    IntCellValue() => value.value.toString(),
    DoubleCellValue() => value.value.toString(),
    BoolCellValue() => value.value ? 'да' : 'нет',
    DateCellValue() => _date(DateTime(value.year, value.month, value.day)),
    DateTimeCellValue() => _date(
      DateTime(value.year, value.month, value.day, value.hour, value.minute),
    ),
    FormulaCellValue() => value.formula,
    _ => value.toString(),
  };
}

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.'
    '${value.month.toString().padLeft(2, '0')}.'
    '${value.year}';

String _cell(List<String> row, int? index) {
  if (index == null || index < 0 || index >= row.length) return '';
  return row[index];
}

InstitutionType _type(String value) {
  final normalized = normalizeImportText(value);
  if (normalized.contains('школ')) return InstitutionType.school;
  if (normalized.contains('сад') || normalized.contains('дошкол')) {
    return InstitutionType.kindergarten;
  }
  return InstitutionType.other;
}

InstitutionStatus _status(String value) {
  final normalized = normalizeImportText(value);
  if (normalized.contains('провер')) return InstitutionStatus.verified;
  if (normalized.contains('неактив')) return InstitutionStatus.inactive;
  return InstitutionStatus.active;
}

CounterpartyType _counterparty(String value) {
  final normalized = normalizeImportText(value);
  if (normalized.contains('физ')) return CounterpartyType.individual;
  return CounterpartyType.legal;
}

List<String> _tags(String value) => value
    .split(RegExp(r'[,;]'))
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty)
    .toList();
