import 'package:flutter_test/flutter_test.dart';
import 'package:planetarium_manager/core/company_time.dart';
import 'package:planetarium_manager/core/import_data.dart';
import 'package:planetarium_manager/data/memory_repository.dart';
import 'package:planetarium_manager/services/institution_import_service.dart';
import 'package:planetarium_manager/services/sheets_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  ensureTimeZones();

  test('демо-Таблицы выгружают базу и финансы в одну таблицу', () async {
    final repository = await MemoryRepository.create();
    final gateway = FakeSheetsGateway();
    final service = SheetsService(repository, gateway);
    final company = (await repository.companies()).first;
    await service.setEnabled(true);

    final exported = await service.exportAll(company);
    expect(exported.length, 2);
    expect(
      exported.map((sheet) => sheet.name),
      containsAll(['Учреждения', 'Выручка']),
    );
    expect(
      exported.firstWhere((sheet) => sheet.name == 'Учреждения').rowCount,
      (await repository.institutions(company.id)).length,
    );
    expect(
      exported.firstWhere((sheet) => sheet.name == 'Выручка').rowCount,
      (await repository.revenues(company.id)).length,
    );

    final id = await service.spreadsheetId();
    expect(id, isNotNull);
    final status = await service.status(company);
    expect(status.length, 2);
    await service.exportAll(company);
    expect(await service.spreadsheetId(), id);
    expect(gateway.spreadsheetCount, 1);
  });

  test('при выключенной синхронизации таблица не создаётся', () async {
    final repository = await MemoryRepository.create();
    final gateway = FakeSheetsGateway();
    final service = SheetsService(repository, gateway);
    final company = (await repository.companies()).first;

    expect(await service.exportAll(company), isEmpty);
    expect(await service.spreadsheetId(), isNull);
    expect(gateway.spreadsheetCount, 0);
  });
  test('демо-Таблицы читаются для импорта и принимают новую строку', () async {
    final repository = await MemoryRepository.create();
    final gateway = FakeSheetsGateway();
    final service = SheetsService(repository, gateway);
    final importer = InstitutionImportService(repository);
    final company = (await repository.companies()).first;
    final before = await repository.institutions(company.id);
    await service.setEnabled(true);
    await service.exportAll(company);

    final table = await service.readInstitutions(company);
    expect(table, isNotNull);
    expect(table!.headers, contains('Название'));
    expect(table.rows.length, before.length);

    final rows = await service.appendDemoInstitution(company);
    expect(rows, before.length + 1);
    final updatedTable = await service.readInstitutions(company);
    expect(updatedTable, isNotNull);
    final parsed = parseInstitutions(
      updatedTable!,
      guessInstitutionMapping(updatedTable.headers),
    );
    expect(parsed.errors, isEmpty);
    expect(parsed.drafts.length, before.length + 1);
    expect(parsed.drafts.last.name, 'Демо-учреждение');

    final existingKeys = {
      for (final item in before)
        institutionDedupeKey(
          type: item.type,
          number: item.number,
          city: item.city,
          name: item.name,
        ),
    }..remove('');
    final expectedNew = parsed.drafts
        .where((draft) => !existingKeys.contains(draft.dedupeKey))
        .length;

    final preview = importer.preview(
      existing: before,
      parsed: parsed,
      policy: ImportDuplicatePolicy.skip,
    );
    expect(preview.created, expectedNew);
    expect(preview.skipped, parsed.drafts.length - expectedNew);

    final result = await importer.apply(
      company: company,
      existing: before,
      parsed: parsed,
      policy: ImportDuplicatePolicy.skip,
    );
    expect(result.created, expectedNew);
    expect(result.skipped, parsed.drafts.length - expectedNew);
    expect(
      (await repository.institutions(company.id)).length,
      before.length + expectedNew,
    );
  });
}
