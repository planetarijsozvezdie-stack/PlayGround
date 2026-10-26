import 'dart:async';

import '../core/event_rules.dart';
import '../data/models.dart';
import '../data/repository.dart';

const calendarSyncEnabledKey = 'calendar_sync_enabled';
const calendarLastSyncKey = 'calendar_last_sync_ms';

class CalendarEventDraft {
  const CalendarEventDraft({
    required this.eventId,
    required this.title,
    required this.description,
    required this.location,
    required this.start,
    required this.end,
    required this.timezone,
  });

  final String eventId;
  final String title;
  final String description;
  final String location;
  final DateTime start;
  final DateTime end;
  final String timezone;
}

class CalendarSyncResult {
  const CalendarSyncResult({
    this.created = 0,
    this.updated = 0,
    this.removed = 0,
  });

  final int created;
  final int updated;
  final int removed;

  bool get changed => created + updated + removed > 0;
  bool get isEmpty => !changed;
}

abstract class CalendarGateway {
  Future<String> upsert(CalendarEventDraft draft, {String? remoteId});

  Future<void> delete(String remoteId);

  Future<Set<String>> takeDeletedRemoteIds();

  Future<void> simulateRemoteDeletion(String remoteId);
}

class FakeCalendarGateway implements CalendarGateway {
  final Map<String, CalendarEventDraft> _events = {};
  final Set<String> _deletedRemoteIds = {};
  var _counter = 0;

  int get eventCount => _events.length;

  @override
  Future<String> upsert(CalendarEventDraft draft, {String? remoteId}) async {
    if (remoteId != null && _events.containsKey(remoteId)) {
      _events[remoteId] = draft;
      return remoteId;
    }
    final id = remoteId ?? 'demo-gcal-${++_counter}-${draft.eventId}';
    _events[id] = draft;
    return id;
  }

  @override
  Future<void> delete(String remoteId) async {
    _events.remove(remoteId);
    _deletedRemoteIds.add(remoteId);
  }

  @override
  Future<Set<String>> takeDeletedRemoteIds() async {
    final ids = Set<String>.from(_deletedRemoteIds);
    _deletedRemoteIds.clear();
    return ids;
  }

  @override
  Future<void> simulateRemoteDeletion(String remoteId) async {
    if (!_events.containsKey(remoteId)) {
      throw StateError('Событие не найдено в демо-календаре');
    }
    _events.remove(remoteId);
    _deletedRemoteIds.add(remoteId);
  }
}

class CalendarService {
  CalendarService(this._repository, this._gateway);

  final Repository _repository;
  final CalendarGateway _gateway;

  Future<bool> isEnabled() async =>
      await _repository.setting(calendarSyncEnabledKey, 'false') == 'true';

  Future<void> setEnabled(bool enabled) =>
      _repository.setSetting(calendarSyncEnabledKey, '$enabled');

  Future<DateTime?> lastSyncAt() async {
    final raw = await _repository.setting(calendarLastSyncKey, '');
    final millis = int.tryParse(raw);
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> autoSyncEvent(Event event) async {
    if (!await isEnabled()) return;
    try {
      await syncEvent(event);
    } catch (_) {
      // Локальные данные важнее: сбой календаря не блокирует работу.
    }
  }

  Future<void> autoRemoveEvent(Event event) async {
    if (!await isEnabled()) return;
    try {
      await removeEvent(event);
    } catch (_) {
      // Удаление локальной записи уже выполнено.
    }
  }

  Future<CalendarSyncResult> autoSyncCompany(String companyId) async {
    if (!await isEnabled()) return const CalendarSyncResult();
    try {
      return await syncCompany(companyId);
    } catch (_) {
      return const CalendarSyncResult();
    }
  }

  Future<void> syncEvent(Event event) async {
    if (event.googleEventId == null && event.status == EventStatus.cancelled) {
      return;
    }
    if (event.status == EventStatus.cancelled) {
      if (event.googleEventId == null) return;
      await _gateway.delete(event.googleEventId!);
      await _repository.saveEvent(event.copyWith(clearGoogleEventId: true));
      return;
    }
    final remoteId = await _gateway.upsert(
      _draft(event),
      remoteId: event.googleEventId,
    );
    if (remoteId != event.googleEventId) {
      await _repository.saveEvent(event.copyWith(googleEventId: remoteId));
    }
  }

  Future<void> removeEvent(Event event) async {
    final remoteId = event.googleEventId;
    if (remoteId == null) return;
    await _gateway.delete(remoteId);
  }

  Future<CalendarSyncResult> syncCompany(String companyId) async {
    var created = 0;
    var updated = 0;
    var removed = 0;
    final remoteDeletes = await _gateway.takeDeletedRemoteIds();
    var events = [...await _repository.events(companyId)];
    for (final event in events) {
      final remoteId = event.googleEventId;
      if (remoteId != null && remoteDeletes.contains(remoteId)) {
        await _repository.deleteEvent(event.id);
        removed++;
        events = events.where((item) => item.id != event.id).toList();
        continue;
      }
      if (event.status == EventStatus.cancelled) {
        if (remoteId == null) continue;
        await _gateway.delete(remoteId);
        await _repository.saveEvent(event.copyWith(clearGoogleEventId: true));
        continue;
      }
      final newRemoteId = await _gateway.upsert(
        _draft(event),
        remoteId: remoteId,
      );
      if (newRemoteId != remoteId) {
        await _repository.saveEvent(event.copyWith(googleEventId: newRemoteId));
      }
      if (remoteId == null) {
        created++;
      } else {
        updated++;
      }
    }
    await _repository.setSetting(
      calendarLastSyncKey,
      '${DateTime.now().millisecondsSinceEpoch}',
    );
    return CalendarSyncResult(
      created: created,
      updated: updated,
      removed: removed,
    );
  }

  Future<String?> simulateRemoteDeletion(String companyId) async {
    final events = await _repository.events(companyId);
    Event? target;
    for (final event in events.reversed) {
      if (event.googleEventId != null) {
        target = event;
        break;
      }
    }
    if (target == null) return null;
    await _gateway.simulateRemoteDeletion(target.googleEventId!);
    await syncCompany(companyId);
    return target.institutionName;
  }

  CalendarEventDraft _draft(Event event) {
    final parts = event.timeStart.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final start = DateTime(
      event.date.year,
      event.date.month,
      event.date.day,
      hour,
      minute,
    );
    final description = [
      event.programName,
      'Детей: ${event.childrenCount}',
      'Контакт: ${event.contactPerson}, ${event.contactPhone}',
      if (event.notes.isNotEmpty) event.notes,
    ].where((line) => line.trim().isNotEmpty).join('\n');
    return CalendarEventDraft(
      eventId: event.id,
      title: 'Планетарий · ${event.institutionName}',
      description: description,
      location: event.institutionAddress,
      start: start,
      end: start.add(Duration(minutes: event.durationMinutes)),
      timezone: event.timezone,
    );
  }
}
