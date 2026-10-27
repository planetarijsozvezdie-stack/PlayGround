import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:planetarium_manager/core/company_time.dart';
import 'package:planetarium_manager/data/memory_repository.dart';
import 'package:planetarium_manager/data/models.dart';
import 'package:planetarium_manager/services/drive_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  ensureTimeZones();

  DocumentRecord document(String companyId) => DocumentRecord(
    id: 'd-test',
    companyId: companyId,
    eventId: null,
    type: 'contract',
    number: 'ПЛ-ЛД-Д-2026-0001',
    title: 'Договор',
    filePath: '/tmp/contract.pdf',
    sizeBytes: 12,
    createdAt: DateTime(2026, 10, 27),
  );

  test('демо-Диск выгружает документ и копию в папки компании', () async {
    final repository = await MemoryRepository.create();
    final gateway = FakeDriveGateway();
    final service = DriveService(repository, gateway);
    final company = (await repository.companies()).first;
    await service.setEnabled(true);
    final record = document(company.id);
    await repository.addDocument(record);

    final driveId = await service.uploadDocument(
      company,
      record,
      utf8.encode('%PDF-demo'),
    );
    expect(driveId, isNotNull);
    final stored = (await repository.documents(company.id))
        .firstWhere((item) => item.id == record.id);
    expect(stored.driveFileId, driveId);

    final backup = await service.uploadBackup(company, utf8.encode('{}'));
    expect(backup, isNotNull);
    expect(backup!.folderPath, contains('Резервные копии'));

    final files = await service.listFiles(company);
    expect(files.length, 2);
    expect(files.any((file) => file.name == 'ПЛ-ЛД-Д-2026-0001.pdf'), isTrue);
  });

  test('при выключенной синхронизации файлы не выгружаются', () async {
    final repository = await MemoryRepository.create();
    final gateway = FakeDriveGateway();
    final service = DriveService(repository, gateway);
    final company = (await repository.companies()).first;
    final record = document(company.id);
    await repository.addDocument(record);

    expect(
      await service.uploadDocument(company, record, utf8.encode('%PDF')),
      isNull,
    );
    expect(await service.uploadBackup(company, utf8.encode('{}')), isNull);
    expect(gateway.fileCount, 0);
    expect((await service.listFiles(company)), isEmpty);
  });
}
