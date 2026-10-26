import 'package:flutter_test/flutter_test.dart';
import 'package:planetarium_manager/core/company_time.dart';
import 'package:planetarium_manager/core/event_rules.dart';
import 'package:planetarium_manager/data/memory_repository.dart';
import 'package:planetarium_manager/services/calendar_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  ensureTimeZones();

  const companyId = 'c-lunny';

  test('демо-календарь выгружает события и удаляет локальное при удалении '
      'в Google', () async {
    final repository = await MemoryRepository.create();
    final gateway = FakeCalendarGateway();
    final service = CalendarService(repository, gateway);
    await service.setEnabled(true);

    final result = await service.syncCompany(companyId);
    expect(result.created, greaterThan(0));
    expect(gateway.eventCount, result.created);
    final synced = await repository.events(companyId);
    expect(
      synced.every(
        (event) =>
            event.status == EventStatus.cancelled ||
            event.googleEventId != null,
      ),
      isTrue,
    );

    final target = synced.lastWhere((event) => event.googleEventId != null);
    final before = synced.length;
    final remoteBefore = gateway.eventCount;
    final removedName = await service.simulateRemoteDeletion(companyId);
    expect(removedName, isNotNull);
    final after = await repository.events(companyId);
    expect(after.length, before - 1);
    expect(after.any((event) => event.id == target.id), isFalse);
    expect(gateway.eventCount, remoteBefore - 1);
  });

  test('отмена события убирает его из демо-календаря', () async {
    final repository = await MemoryRepository.create();
    final gateway = FakeCalendarGateway();
    final service = CalendarService(repository, gateway);
    await service.setEnabled(true);
    await service.syncCompany(companyId);

    final events = await repository.events(companyId);
    final target = events.firstWhere(
      (event) =>
          event.googleEventId != null && event.status == EventStatus.scheduled,
    );
    final remoteBefore = gateway.eventCount;
    await repository.cancelEvent(target.id);
    await service.syncEvent(target.copyWith(status: EventStatus.cancelled));

    expect(gateway.eventCount, remoteBefore - 1);
    final refreshed = (await repository.events(companyId))
        .firstWhere((event) => event.id == target.id);
    expect(refreshed.googleEventId, isNull);
  });

  test('при выключенной синхронизации события не выгружаются', () async {
    final repository = await MemoryRepository.create();
    final gateway = FakeCalendarGateway();
    final service = CalendarService(repository, gateway);

    final result = await service.autoSyncCompany(companyId);
    expect(result.isEmpty, isTrue);
    expect(gateway.eventCount, 0);
    final events = await repository.events(companyId);
    expect(events.every((event) => event.googleEventId == null), isTrue);
  });
}
