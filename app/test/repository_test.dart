import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:planetarium_manager/core/backup_data.dart';
import 'package:planetarium_manager/core/company_time.dart';
import 'package:planetarium_manager/core/pin.dart';
import 'package:planetarium_manager/core/tax.dart';
import 'package:planetarium_manager/services/biometric_service.dart';
import 'package:planetarium_manager/state/providers.dart';
import 'package:planetarium_manager/data/memory_repository.dart';
import 'package:planetarium_manager/data/models.dart';
import 'package:planetarium_manager/data/sqlite_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  ensureTimeZones();

  late SqliteRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    repository = await SqliteRepository.open(path: inMemoryDatabasePath);
  });

  tearDown(() async {
    await repository.dispose();
  });

  Future<Event> createEvent(
    String companyId, {
    String id = 'e-test',
    String institutionId = '',
  }) async {
    final company = (await repository.companies()).firstWhere(
      (c) => c.id == companyId,
    );
    final institutions = await repository.institutions(companyId);
    final institution = institutionId.isEmpty
        ? institutions.first
        : institutions.firstWhere((i) => i.id == institutionId);
    final event = Event.draft(
      id: id,
      companyId: companyId,
      institution: institution,
      date: todayInCompany(company.timezone).add(const Duration(days: 5)),
      timeStart: '09:00',
      timezone: company.timezone,
      programName: 'Тестовая программа',
      childrenCount: 25,
      pricePerChildKopecks: 25000,
      institutionPercentBp: 2500,
    );
    await repository.saveEvent(event);
    return event;
  }

  Future<int> revenueSum(String companyId) async {
    final revenues = await repository.revenues(companyId);
    return revenues.fold<int>(0, (sum, item) => sum + item.amountKopecks);
  }

  test('сид создаёт две компании и не смешивает данные', () async {
    final companies = await repository.companies();
    expect(companies.length, 2);

    final ufa = await repository.institutions('c-lunny');
    expect(ufa, isNotEmpty);
    expect(ufa.every((i) => i.companyId == 'c-lunny'), isTrue);
    expect(ufa.any((i) => i.id == 'i-nn-10'), isFalse);

    final revenues = await repository.revenues('c-lunny');
    expect(revenues, isNotEmpty);
    expect(revenues.every((r) => r.companyId == 'c-lunny'), isTrue);
    expect(revenues.any((r) => r.isAuto), isTrue);
  });

  test('завершение идемпотентно и начисляет ровно одну авто-запись', () async {
    final event = await createEvent('c-lunny', id: 'e-complete');
    await repository.completeEvent(event.id);

    var revenues = await repository.revenues('c-lunny');
    final auto = revenues
        .where((r) => r.eventId == event.id && r.isAuto)
        .toList();
    expect(auto.length, 1);
    expect(auto.first.amountKopecks, event.netKopecks);

    await repository.completeEvent(event.id);
    revenues = await repository.revenues('c-lunny');
    expect(revenues.where((r) => r.eventId == event.id && r.isAuto).length, 1);
  });

  test('отмена завершённого сторнирует выручку и возвращает вычет', () async {
    final beforeSum = await revenueSum('c-lunny');
    final beforeStats = await repository.stats('c-lunny');
    final event = await createEvent('c-lunny', id: 'e-cancel');

    await repository.completeEvent(event.id);
    expect(await revenueSum('c-lunny'), beforeSum + event.netKopecks);

    final afterComplete = await repository.stats('c-lunny');
    expect(
      afterComplete.deductionRemainingKopecks,
      lessThan(beforeStats.deductionRemainingKopecks),
    );

    await repository.cancelEvent(event.id);
    expect(await revenueSum('c-lunny'), beforeSum);

    final afterCancel = await repository.stats('c-lunny');
    expect(
      afterCancel.deductionRemainingKopecks,
      beforeStats.deductionRemainingKopecks,
    );

    final revenues = await repository.revenues('c-lunny');
    final reversal = revenues.where((r) => r.reversalOfId != null);
    expect(reversal, isNotEmpty);
    expect(reversal.last.amountKopecks, -event.netKopecks);
  });

  test('возврат в план сторнирует выручку', () async {
    final before = await revenueSum('c-lunny');
    final event = await createEvent('c-lunny', id: 'e-reopen');
    await repository.completeEvent(event.id);
    await repository.reopenEvent(event.id);

    expect(await revenueSum('c-lunny'), before);
    final events = await repository.events('c-lunny');
    expect(events.firstWhere((e) => e.id == event.id).status.name, 'scheduled');
  });

  test('режим подтверждения не создаёт авто-выручку', () async {
    await repository.setSetting('revenue_mode', 'confirm');
    final before = (await repository.revenues('c-lunny')).length;
    final event = await createEvent('c-lunny', id: 'e-confirm');
    await repository.completeEvent(event.id);
    final after = await repository.revenues('c-lunny');
    expect(after.length, before);
    expect(after.any((r) => r.eventId == event.id), isFalse);
  });

  test('снапшот учреждения не меняется при переименовании', () async {
    final institutions = await repository.institutions('c-lunny');
    final original = institutions.first;
    final event = await createEvent(
      'c-lunny',
      id: 'e-snapshot',
      institutionId: original.id,
    );
    await repository.completeEvent(event.id);

    await repository.saveInstitution(original.copyWith(name: 'Новое имя'));

    final events = await repository.events('c-lunny');
    final stored = events.firstWhere((e) => e.id == event.id);
    expect(stored.institutionName, original.displayName);
    expect(stored.institutionName, isNot('Новое имя'));
  });

  test('мягкое удаление и восстановление мероприятия', () async {
    final event = await createEvent('c-lunny', id: 'e-soft');
    await repository.deleteEvent(event.id);
    expect(
      (await repository.events('c-lunny')).any((e) => e.id == event.id),
      isFalse,
    );
    await repository.restoreEvent(event.id);
    expect(
      (await repository.events('c-lunny')).any((e) => e.id == event.id),
      isTrue,
    );
  });

  test('ручная выручка считает 6% для юрлица', () async {
    final revenue = Revenue(
      id: 'r-manual',
      companyId: 'c-lunny',
      eventId: null,
      date: DateTime.now(),
      amountKopecks: 100000,
      grossKopecks: null,
      category: 'other',
      counterparty: CounterpartyType.legal,
      taxRateBp: 0,
      taxBaseKopecks: 0,
      taxDeductionKopecks: 0,
      taxAmountKopecks: 0,
      isAuto: false,
      isReversed: false,
      reversalOfId: null,
      comment: 'Ручная запись',
    );
    await repository.addRevenue(revenue);

    final stored = (await repository.revenues('c-lunny'))
        .firstWhere((r) => r.id == 'r-manual');
    expect(stored.taxRateBp, 600);
    expect(stored.taxAmountKopecks, greaterThan(0));
    expect(stored.taxAmountKopecks, lessThanOrEqualTo(6000));
    expect(stored.taxDeductionKopecks, greaterThan(0));
  });

  test('выбор компании сохраняется', () async {
    expect(await repository.selectedCompanyId(), isNull);
    await repository.selectCompany('c-lunny');
    expect(await repository.selectedCompanyId(), 'c-lunny');
  });

  test('журнал изменений фиксирует правку учреждения', () async {
    final institution = (await repository.institutions('c-lunny')).first;
    await repository.saveInstitution(
      institution.copyWith(phonePrimary: '+7 999 000-00-00'),
    );
    final history = await repository.institutionHistory(institution.id);
    expect(history, isNotEmpty);
    expect(history.first.field, 'phone_primary');
    expect(history.first.newValue, '+7 999 000-00-00');
  });

  test('очередь синхронизации растёт при записи', () async {
    final before = await repository.pendingOutbox();
    await createEvent('c-lunny', id: 'e-outbox');
    expect(await repository.pendingOutbox(), greaterThan(before));
  });

  test('резервная копия восстанавливает данные и настройки', () async {
    await repository.setSetting('profile_name', 'Марина');
    final backup = await repository.exportBackup();
    expect(backup['format'], backupFormat);
    expect(backup['version'], backupVersion);
    expect((backup['tables'] as Map)['companies'], isNotEmpty);

    await repository.setSetting('profile_name', 'Другое');
    final event = await createEvent('c-lunny', id: 'e-backup');
    await repository.completeEvent(event.id);
    expect(
      (await repository.revenues('c-lunny'))
          .any((r) => r.eventId == 'e-backup'),
      isTrue,
    );

    final decoded = jsonDecode(jsonEncode(backup)) as Map<String, dynamic>;
    await repository.restoreBackup(decoded);

    expect(await repository.setting('profile_name', ''), 'Марина');
    expect(
      (await repository.events('c-lunny')).any((e) => e.id == 'e-backup'),
      isFalse,
    );
    expect(
      (await repository.revenues('c-lunny'))
          .any((r) => r.eventId == 'e-backup'),
      isFalse,
    );
    expect((await repository.companies()).length, 2);
  });

  test('биометрия не разблокирует без включённой настройки', () async {
    final lock = LockController(repository);
    expect(await lock.unlockWithBiometrics(), isFalse);
    await repository.setSetting(biometricEnabledKey, '1');
    expect(await lock.unlockWithBiometrics(), isTrue);
    lock.dispose();
  });

  test(
    'после пяти неверных PIN включается пауза, биометрия её снимает',
    () async {
      final stored = hashPinPbkdf2('4271', iterations: 1000);
      await repository.setSetting(pinHashKey, stored.hash);
      await repository.setSetting(pinSaltKey, stored.salt);
      await repository.setSetting(pinIterationsKey, '${stored.iterations}');
      final lock = LockController(repository);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      for (var attempt = 0; attempt < pinSoftLockAttempts; attempt++) {
        expect(await lock.unlock('1111'), isFalse);
      }
      expect(lock.state.failedAttempts, pinSoftLockAttempts);
      expect(lock.state.blocked, isTrue);
      expect(await lock.unlock('4271'), isFalse);

      final restarted = LockController(repository);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(restarted.state.blocked, isTrue);

      await repository.setSetting(biometricEnabledKey, '1');
      expect(await restarted.unlockWithBiometrics(), isTrue);
      expect(restarted.state.failedAttempts, 0);
      expect(restarted.state.blocked, isFalse);
      expect(await restarted.unlock('4271'), isTrue);
      lock.dispose();
      restarted.dispose();
    },
  );

  test('документ подписывается и скрывается после удаления', () async {
    final document = DocumentRecord(
      id: 'd-test',
      companyId: 'c-lunny',
      eventId: null,
      type: 'contract',
      number: 'ПЛ-ЛД-Д-2026-9999',
      title: 'Тестовый договор',
      filePath: '/tmp/test.pdf',
      sizeBytes: 100,
      createdAt: DateTime.utc(2026, 10, 21),
    );
    await repository.addDocument(document);
    expect((await repository.documents('c-lunny')).single.signed, isFalse);
    await repository.setDocumentSigned(document.id, true);
    final signed = (await repository.documents('c-lunny')).single;
    expect(signed.signed, isTrue);
    expect(signed.signedDate, isNotNull);
    await repository.setDocumentSigned(document.id, false);
    expect((await repository.documents('c-lunny')).single.signed, isFalse);
    await repository.deleteDocument(document.id);
    expect(
      (await repository.documents('c-lunny')).any((d) => d.id == document.id),
      isFalse,
    );
  });

  test('in-memory документ подписывается и удаляется', () async {
    final memory = await MemoryRepository.create();
    final document = DocumentRecord(
      id: 'd-memory',
      companyId: 'c-lunny',
      eventId: null,
      type: 'act',
      number: 'ПЛ-ЛД-А-2026-9998',
      title: 'Тестовый акт',
      filePath: null,
      sizeBytes: null,
      createdAt: DateTime.utc(2026, 10, 21),
    );
    await memory.addDocument(document);
    await memory.setDocumentSigned(document.id, true);
    expect((await memory.documents('c-lunny')).single.signed, isTrue);
    await memory.deleteDocument(document.id);
    expect(
      (await memory.documents('c-lunny')).any((d) => d.id == document.id),
      isFalse,
    );
  });

  test('in-memory корзина и сброс компании', () async {
    final memory = await MemoryRepository.create();
    final institution = (await memory.institutions('c-lunny')).first;
    await memory.deleteInstitution(institution.id);
    expect(
      (await memory.trash('c-lunny'))
          .any((entry) => entry.kind == TrashKind.institution),
      isTrue,
    );
    await memory.restoreTrash(TrashKind.institution, institution.id);
    expect(
      (await memory.institutions('c-lunny')).any((i) => i.id == institution.id),
      isTrue,
    );
    await memory.deleteInstitution(institution.id);
    expect(await memory.purgeTrash('c-lunny'), 1);
    await memory.resetCompanyData('c-lunny');
    expect(await memory.institutions('c-lunny'), isEmpty);
    expect(await memory.revenues('c-lunny'), isEmpty);
    expect((await memory.companies()).any((c) => c.id == 'c-lunny'), isTrue);
    expect(await memory.institutions('c-sozvezdie'), isNotEmpty);
  });

  test('корзина восстанавливает учреждения и документы', () async {
    final institution = (await repository.institutions('c-lunny')).first;
    await repository.deleteInstitution(institution.id);
    final document = DocumentRecord(
      id: 'd-trash',
      companyId: 'c-lunny',
      eventId: null,
      type: 'act',
      number: 'TR-1',
      title: 'Документ в корзине',
      filePath: null,
      sizeBytes: null,
      createdAt: DateTime.utc(2026, 10, 28),
    );
    await repository.addDocument(document);
    await repository.deleteDocument(document.id);

    final entries = await repository.trash('c-lunny');
    expect(entries.any((e) => e.kind == TrashKind.institution), isTrue);
    expect(entries.any((e) => e.kind == TrashKind.document), isTrue);
    expect(
      (await repository.institutions('c-lunny'))
          .any((i) => i.id == institution.id),
      isFalse,
    );

    await repository.restoreTrash(TrashKind.institution, institution.id);
    await repository.restoreTrash(TrashKind.document, document.id);
    expect(
      (await repository.institutions('c-lunny'))
          .any((i) => i.id == institution.id),
      isTrue,
    );
    expect(
      (await repository.documents('c-lunny')).any((d) => d.id == document.id),
      isTrue,
    );
    expect(await repository.trash('c-lunny'), isEmpty);
  });

  test('очистка корзины удаляет записи физически', () async {
    final institution = (await repository.institutions('c-lunny')).first;
    await repository.deleteInstitution(institution.id);
    expect(await repository.purgeTrash('c-lunny'), 1);
    expect(await repository.trash('c-lunny'), isEmpty);
    expect(
      (await repository.institutions('c-lunny'))
          .any((i) => i.id == institution.id),
      isFalse,
    );
    await repository.restoreTrash(TrashKind.institution, institution.id);
    expect(
      (await repository.institutions('c-lunny'))
          .any((i) => i.id == institution.id),
      isFalse,
    );
  });

  test('сброс компании очищает данные, но сохраняет компанию', () async {
    await repository.resetCompanyData('c-lunny');
    expect(await repository.institutions('c-lunny'), isEmpty);
    expect(await repository.events('c-lunny'), isEmpty);
    expect(await repository.revenues('c-lunny'), isEmpty);
    expect(await repository.documents('c-lunny'), isEmpty);
    expect(await repository.programs('c-lunny'), isEmpty);
    expect(await repository.templates('c-lunny'), isEmpty);
    expect(
      (await repository.companies()).any((c) => c.id == 'c-lunny'),
      isTrue,
    );
    expect(await repository.institutions('c-sozvezdie'), isNotEmpty);
  });

  test('шаблон договора сохраняется', () async {
    final original = (await repository.templates('c-lunny')).first;
    await repository.saveTemplate(
      TemplateRecord(
        id: original.id,
        companyId: original.companyId,
        type: original.type,
        name: original.name,
        body: 'Новый текст {{institution_name}}',
      ),
    );
    final updated = (await repository.templates('c-lunny'))
        .firstWhere((template) => template.id == original.id);
    expect(updated.body, 'Новый текст {{institution_name}}');
  });

  test('старый PIN обновляется до Argon2id после входа', () async {
    final memory = await MemoryRepository.create();
    final legacy = hashPinPbkdf2('4271', iterations: 1000);
    await memory.setSetting(pinHashKey, legacy.hash);
    await memory.setSetting(pinSaltKey, legacy.salt);
    await memory.setSetting(pinIterationsKey, '${legacy.iterations}');
    await memory.setSetting(pinAlgorithmKey, legacy.algorithm);

    final controller = LockController(memory);
    expect(await controller.unlock('4271'), isTrue);
    var algorithm = '';
    for (var i = 0; i < 50; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      algorithm = await memory.setting(pinAlgorithmKey, '');
      if (algorithm == pinAlgorithmArgon2id) break;
    }
    expect(algorithm, pinAlgorithmArgon2id);
    expect(await memory.setting(pinIterationsKey, ''), '$pinArgon2Iterations');
    controller.dispose();
  });

  test('повреждённая копия отклоняется без изменения данных', () async {
    expect(
      () => repository.restoreBackup({'format': 'other', 'version': 1}),
      throwsFormatException,
    );
    expect((await repository.companies()).length, 2);
  });
}
