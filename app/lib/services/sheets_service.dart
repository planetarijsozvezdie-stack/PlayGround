import '../core/export_data.dart';
import '../data/models.dart';
import '../data/repository.dart';

const sheetsSyncEnabledKey = 'google_sheets_sync_enabled';
const sheetsSpreadsheetIdKey = 'google_sheets_spreadsheet_id';
const sheetsLastSyncKey = 'google_sheets_last_sync_ms';

class SheetInfo {
  const SheetInfo({required this.name, required this.rowCount});

  final String name;
  final int rowCount;
}

abstract class SheetsGateway {
  Future<String> ensureSpreadsheet({
    required String title,
    String? spreadsheetId,
  });

  Future<void> writeSheet({
    required String spreadsheetId,
    required String sheetName,
    required List<String> headers,
    required List<List<String>> rows,
  });

  Future<List<SheetInfo>> sheets(String spreadsheetId);
}

class FakeSheetsGateway implements SheetsGateway {
  final Map<String, Map<String, List<List<String>>>> _spreadsheets = {};
  final Map<String, String> _titles = {};
  var _counter = 0;

  int get spreadsheetCount => _spreadsheets.length;

  @override
  Future<String> ensureSpreadsheet({
    required String title,
    String? spreadsheetId,
  }) async {
    final id = spreadsheetId ?? 'demo-sheet-${++_counter}';
    _spreadsheets.putIfAbsent(id, () => {});
    _titles[id] = title;
    return id;
  }

  @override
  Future<void> writeSheet({
    required String spreadsheetId,
    required String sheetName,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    final spreadsheet = _spreadsheets.putIfAbsent(spreadsheetId, () => {});
    spreadsheet[sheetName] = [headers, ...rows];
  }

  @override
  Future<List<SheetInfo>> sheets(String spreadsheetId) async {
    final spreadsheet = _spreadsheets[spreadsheetId] ?? const {};
    return [
      for (final entry in spreadsheet.entries)
        SheetInfo(
          name: entry.key,
          rowCount: entry.value.isEmpty ? 0 : entry.value.length - 1,
        ),
    ];
  }
}

class SheetsService {
  SheetsService(this._repository, this._gateway);

  final Repository _repository;
  final SheetsGateway _gateway;

  Future<bool> isEnabled() async =>
      await _repository.setting(sheetsSyncEnabledKey, 'false') == 'true';

  Future<void> setEnabled(bool enabled) =>
      _repository.setSetting(sheetsSyncEnabledKey, '$enabled');

  Future<DateTime?> lastSyncAt() async {
    final raw = await _repository.setting(sheetsLastSyncKey, '');
    final millis = int.tryParse(raw);
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<String?> spreadsheetId() async {
    final value = await _repository.setting(sheetsSpreadsheetIdKey, '');
    return value.isEmpty ? null : value;
  }

  String spreadsheetTitle(Company company) =>
      'Планетарий · ${company.shortName}';

  Future<List<SheetInfo>> status(Company company) async {
    final id = await spreadsheetId();
    if (id == null) return const [];
    return _gateway.sheets(id);
  }

  Future<SheetInfo?> exportInstitutions(Company company) async {
    if (!await isEnabled()) return null;
    final id = await _ensureSpreadsheet(company);
    final table = institutionsTable(await _repository.institutions(company.id));
    await _gateway.writeSheet(
      spreadsheetId: id,
      sheetName: table.sheetName,
      headers: table.headers,
      rows: table.rows,
    );
    await _touch();
    return SheetInfo(name: table.sheetName, rowCount: table.rows.length);
  }

  Future<SheetInfo?> exportRevenues(Company company) async {
    if (!await isEnabled()) return null;
    final id = await _ensureSpreadsheet(company);
    final table = revenuesTable(await _repository.revenues(company.id));
    await _gateway.writeSheet(
      spreadsheetId: id,
      sheetName: table.sheetName,
      headers: table.headers,
      rows: table.rows,
    );
    await _touch();
    return SheetInfo(name: table.sheetName, rowCount: table.rows.length);
  }

  Future<List<SheetInfo>> exportAll(Company company) async {
    final institutions = await exportInstitutions(company);
    final revenues = await exportRevenues(company);
    return [?institutions, ?revenues];
  }

  Future<String> _ensureSpreadsheet(Company company) async {
    final existing = await spreadsheetId();
    final id = await _gateway.ensureSpreadsheet(
      title: spreadsheetTitle(company),
      spreadsheetId: existing,
    );
    if (id != existing) {
      await _repository.setSetting(sheetsSpreadsheetIdKey, id);
    }
    return id;
  }

  Future<void> _touch() => _repository.setSetting(
    sheetsLastSyncKey,
    '${DateTime.now().millisecondsSinceEpoch}',
  );
}
