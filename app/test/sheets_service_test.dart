import 'package:flutter_test/flutter_test.dart';
import 'package:planetarium_manager/core/company_time.dart';
import 'package:planetarium_manager/data/memory_repository.dart';
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
}
