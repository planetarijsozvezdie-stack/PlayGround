import 'dart:math';

import 'package:uuid/uuid.dart';

import '../core/company_time.dart';
import '../core/event_rules.dart';
import '../core/tax.dart';
import 'models.dart';
import 'repository.dart';
import 'seed.dart';

const _uuid = Uuid();

class MemoryRepository implements Repository {
  MemoryRepository._();

  static Future<MemoryRepository> create() async {
    final repository = MemoryRepository._();
    await repository._seed();
    return repository;
  }

  final List<Company> _companies = [];
  final List<Institution> _institutions = [];
  final List<Event> _events = [];
  final List<Revenue> _revenues = [];
  final List<ProgramRecord> _programs = [];
  final List<TemplateRecord> _templates = [];
  final List<DocumentRecord> _documents = [];
  final Map<String, List<ChangeEntry>> _history = {};
  final Map<String, int> _deductionUsed = {};
  final Map<String, String> _settings = {};
  final List<String> _outbox = [];
  final Map<String, String> _deletedEvents = {};
  String? _selectedCompanyId;

  @override
  Future<List<Company>> companies() async => List.unmodifiable(_companies);

  @override
  Future<String?> selectedCompanyId() async => _selectedCompanyId;

  @override
  Future<void> selectCompany(String companyId) async {
    _selectedCompanyId = companyId;
    _settings['selected_company_id'] = companyId;
  }

  @override
  Future<String> setting(String key, String fallback) async =>
      _settings[key] ?? fallback;

  @override
  Future<void> setSetting(String key, String value) async {
    _settings[key] = value;
  }

  @override
  Future<List<Institution>> institutions(
    String companyId, {
    InstitutionType? type,
  }) async {
    final result =
        _institutions
            .where(
              (i) =>
                  i.companyId == companyId &&
                  (type == null || i.type == type) &&
                  !_institutionsDeleted.contains(i.id),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  final Set<String> _institutionsDeleted = {};

  @override
  Future<void> saveInstitution(Institution value) async {
    final index = _institutions.indexWhere((i) => i.id == value.id);
    if (index == -1) {
      _institutions.add(value);
      _history
          .putIfAbsent(value.id, () => [])
          .insert(
            0,
            ChangeEntry(
              field: '*',
              oldValue: '',
              newValue: 'создано',
              changedAt: DateTime.now(),
            ),
          );
    } else {
      final previous = _institutions[index];
      _institutions[index] = value;
      _logInstitutionDiff(previous, value);
    }
    _outbox.add('institutions:${value.id}');
  }

  @override
  Future<void> deleteInstitution(String id) async {
    _institutionsDeleted.add(id);
    _outbox.add('institutions:$id');
  }

  @override
  Future<List<ChangeEntry>> institutionHistory(String institutionId) async =>
      List.unmodifiable(_history[institutionId] ?? const []);

  @override
  Future<List<Event>> events(String companyId, {EventStatus? status}) async {
    final result =
        _events
            .where(
              (e) =>
                  e.companyId == companyId &&
                  (status == null || e.status == status) &&
                  !_deletedEvents.containsKey(e.id),
            )
            .toList()
          ..sort((a, b) {
            final d = a.date.compareTo(b.date);
            return d != 0 ? d : a.timeStart.compareTo(b.timeStart);
          });
    return result;
  }

  @override
  Future<void> saveEvent(Event value) async {
    final index = _events.indexWhere((e) => e.id == value.id);
    if (index == -1) {
      _events.add(value);
    } else {
      _events[index] = value.copyWith(status: _events[index].status);
    }
    _outbox.add('events:${value.id}');
  }

  @override
  Future<void> completeEvent(String id) async {
    final index = _events.indexWhere((e) => e.id == id);
    if (index == -1) return;
    final event = _events[index];
    if (event.status != EventStatus.scheduled) return;
    _events[index] = event.copyWith(status: EventStatus.completed);
    final mode = RevenueMode.fromDb(_settings['revenue_mode'] ?? 'auto');
    if (mode == RevenueMode.auto) {
      _createAutoRevenue(event);
    }
    _adjustVisits(event, 1);
    _outbox.add('events:$id');
  }

  @override
  Future<void> cancelEvent(String id) async {
    final index = _events.indexWhere((e) => e.id == id);
    if (index == -1) return;
    final event = _events[index];
    if (event.status == EventStatus.cancelled) return;
    if (event.status == EventStatus.completed) {
      _reverseAutoRevenue(event);
      _adjustVisits(event, -1);
    }
    _events[index] = event.copyWith(status: EventStatus.cancelled);
    _outbox.add('events:$id');
  }

  @override
  Future<void> reopenEvent(String id) async {
    final index = _events.indexWhere((e) => e.id == id);
    if (index == -1) return;
    final event = _events[index];
    if (event.status == EventStatus.scheduled) return;
    if (event.status == EventStatus.completed) {
      _reverseAutoRevenue(event);
      _adjustVisits(event, -1);
    }
    _events[index] = event.copyWith(status: EventStatus.scheduled);
    _outbox.add('events:$id');
  }

  @override
  Future<void> deleteEvent(String id) async {
    final index = _events.indexWhere((e) => e.id == id);
    if (index == -1) return;
    final event = _events[index];
    if (event.status == EventStatus.completed) {
      _reverseAutoRevenue(event);
      _adjustVisits(event, -1);
    }
    _deletedEvents[id] = DateTime.now().toIso8601String();
    _outbox.add('events:$id');
  }

  @override
  Future<void> restoreEvent(String id) async {
    _deletedEvents.remove(id);
    _outbox.add('events:$id');
  }

  @override
  Future<List<Revenue>> revenues(String companyId) async {
    final result = _revenues.where((r) => r.companyId == companyId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  @override
  Future<void> addRevenue(Revenue value) async {
    final used = _deductionUsed[value.companyId] ?? 0;
    final tax = TaxCalculator.calculate(
      taxBaseKopecks: value.amountKopecks,
      counterparty: value.counterparty,
      deductionRemainingKopecks: TaxCalculator.deductionLimitKopecks - used,
    );
    _revenues.add(
      Revenue(
        id: value.id,
        companyId: value.companyId,
        eventId: value.eventId,
        date: value.date,
        amountKopecks: value.amountKopecks,
        grossKopecks: value.grossKopecks,
        category: value.category,
        counterparty: value.counterparty,
        taxRateBp: tax.rateBp,
        taxBaseKopecks: value.amountKopecks,
        taxDeductionKopecks: tax.deductionAppliedKopecks,
        taxAmountKopecks: tax.taxAmountKopecks,
        isAuto: false,
        isReversed: false,
        reversalOfId: null,
        comment: value.comment,
      ),
    );
    _deductionUsed[value.companyId] = used + tax.deductionAppliedKopecks;
    _outbox.add('revenues:${value.id}');
  }

  @override
  Future<DashboardStats> stats(String companyId) async {
    final company = _companies.firstWhere((c) => c.id == companyId);
    final today = todayInCompany(company.timezone);
    final key = monthKey(today);
    final monthEvents = _events.where(
      (e) =>
          e.companyId == companyId &&
          !_deletedEvents.containsKey(e.id) &&
          monthKey(e.date) == key,
    );
    final monthRevenues = _revenues.where(
      (r) => r.companyId == companyId && monthKey(r.date) == key,
    );
    final used = _deductionUsed[companyId] ?? 0;
    return DashboardStats(
      completedSessions: monthEvents
          .where((e) => e.status == EventStatus.completed)
          .length,
      revenueKopecks: monthRevenues.fold(0, (sum, r) => sum + r.amountKopecks),
      plannedEvents: _events
          .where(
            (e) =>
                e.companyId == companyId &&
                e.status == EventStatus.scheduled &&
                !_deletedEvents.containsKey(e.id) &&
                !e.date.isBefore(today),
          )
          .length,
      taxKopecks: monthRevenues.fold(0, (sum, r) => sum + r.taxAmountKopecks),
      deductionRemainingKopecks: TaxCalculator.deductionLimitKopecks - used,
    );
  }

  @override
  Future<List<ProgramRecord>> programs(String companyId) async =>
      _programs.where((p) => p.companyId == companyId).toList();

  @override
  Future<List<TemplateRecord>> templates(String companyId) async =>
      _templates.where((t) => t.companyId == companyId).toList();

  @override
  Future<List<DocumentRecord>> documents(String companyId) async =>
      _documents.where((d) => d.companyId == companyId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<void> addDocument(DocumentRecord value) async {
    _documents.add(value);
    _outbox.add('documents:${value.id}');
  }

  @override
  Future<void> setDocumentSigned(String id, bool signed) async {
    final index = _documents.indexWhere((document) => document.id == id);
    if (index < 0) return;
    _documents[index] = _documents[index].copyWith(
      signed: signed,
      signedDate: signed ? DateTime.now() : null,
    );
    _outbox.add('documents:$id');
  }

  @override
  Future<void> deleteDocument(String id) async {
    _documents.removeWhere((document) => document.id == id);
    _outbox.add('documents:$id');
  }

  @override
  Future<int> pendingOutbox() async => _outbox.length;

  @override
  @override
  bool get supportsFullBackup => false;

  @override
  Future<Map<String, dynamic>> exportBackup() async {
    throw UnsupportedError(
      'Резервная копия доступна в приложении на устройстве',
    );
  }

  @override
  Future<void> restoreBackup(Map<String, dynamic> backup) async {
    throw UnsupportedError(
      'Резервная копия доступна в приложении на устройстве',
    );
  }

  @override
  Future<void> dispose() async {}

  void _createAutoRevenue(Event event) {
    final hasAuto = _revenues.any(
      (r) => r.eventId == event.id && r.isAuto && !r.isReversed,
    );
    if (hasAuto) return;
    final taxBaseMode = TaxBaseMode.fromDb(_settings['tax_base'] ?? 'received');
    final base = taxBaseMode == TaxBaseMode.gross
        ? event.grossKopecks
        : event.netKopecks;
    final institution = _institutions.where((i) => i.id == event.institutionId);
    final counterparty = institution.isEmpty
        ? CounterpartyType.legal
        : institution.first.counterparty;
    final used = _deductionUsed[event.companyId] ?? 0;
    final tax = TaxCalculator.calculate(
      taxBaseKopecks: base,
      counterparty: counterparty,
      deductionRemainingKopecks: TaxCalculator.deductionLimitKopecks - used,
    );
    _revenues.add(
      Revenue(
        id: _uuid.v4(),
        companyId: event.companyId,
        eventId: event.id,
        date: event.date,
        amountKopecks: base,
        grossKopecks: event.grossKopecks,
        category: 'session',
        counterparty: counterparty,
        taxRateBp: tax.rateBp,
        taxBaseKopecks: base,
        taxDeductionKopecks: tax.deductionAppliedKopecks,
        taxAmountKopecks: tax.taxAmountKopecks,
        isAuto: true,
        isReversed: false,
        reversalOfId: null,
        comment: 'Автоначисление: ${event.institutionName}',
      ),
    );
    _deductionUsed[event.companyId] = used + tax.deductionAppliedKopecks;
  }

  void _reverseAutoRevenue(Event event) {
    final index = _revenues.indexWhere(
      (r) => r.eventId == event.id && r.isAuto && !r.isReversed,
    );
    if (index == -1) return;
    final original = _revenues[index];
    _revenues[index] = Revenue(
      id: original.id,
      companyId: original.companyId,
      eventId: original.eventId,
      date: original.date,
      amountKopecks: original.amountKopecks,
      grossKopecks: original.grossKopecks,
      category: original.category,
      counterparty: original.counterparty,
      taxRateBp: original.taxRateBp,
      taxBaseKopecks: original.taxBaseKopecks,
      taxDeductionKopecks: original.taxDeductionKopecks,
      taxAmountKopecks: original.taxAmountKopecks,
      isAuto: false,
      isReversed: true,
      reversalOfId: original.reversalOfId,
      comment: original.comment,
    );
    _revenues.add(
      Revenue(
        id: _uuid.v4(),
        companyId: original.companyId,
        eventId: original.eventId,
        date: original.date,
        amountKopecks: -original.amountKopecks,
        grossKopecks: original.grossKopecks == null
            ? null
            : -original.grossKopecks!,
        category: original.category,
        counterparty: original.counterparty,
        taxRateBp: original.taxRateBp,
        taxBaseKopecks: -original.taxBaseKopecks,
        taxDeductionKopecks: -original.taxDeductionKopecks,
        taxAmountKopecks: -original.taxAmountKopecks,
        isAuto: false,
        isReversed: true,
        reversalOfId: original.id,
        comment: 'Сторно: ${event.institutionName}',
      ),
    );
    _deductionUsed[event.companyId] = max(
      0,
      (_deductionUsed[event.companyId] ?? 0) - original.taxDeductionKopecks,
    );
  }

  void _adjustVisits(Event event, int delta) {
    if (event.institutionId == null) return;
    final index = _institutions.indexWhere((i) => i.id == event.institutionId);
    if (index == -1) return;
    final institution = _institutions[index];
    _institutions[index] = Institution(
      id: institution.id,
      companyId: institution.companyId,
      type: institution.type,
      number: institution.number,
      name: institution.name,
      city: institution.city,
      district: institution.district,
      address: institution.address,
      contactPerson: institution.contactPerson,
      position: institution.position,
      phonePrimary: institution.phonePrimary,
      phoneSecondary: institution.phoneSecondary,
      email: institution.email,
      website: institution.website,
      groupsCount: institution.groupsCount,
      hallCapacity: institution.hallCapacity,
      notes: institution.notes,
      lastVisitDate: delta > 0 ? event.date : institution.lastVisitDate,
      totalVisits: max(0, institution.totalVisits + delta),
      status: institution.status,
      tags: institution.tags,
      counterparty: institution.counterparty,
      externalId: institution.externalId,
    );
  }

  void _logInstitutionDiff(Institution previous, Institution next) {
    void add(String field, String before, String after) {
      if (before == after) return;
      _history
          .putIfAbsent(next.id, () => [])
          .insert(
            0,
            ChangeEntry(
              field: field,
              oldValue: before,
              newValue: after,
              changedAt: DateTime.now(),
            ),
          );
    }

    add('name', previous.name, next.name);
    add('city', previous.city, next.city);
    add('address', previous.address, next.address);
    add('contact_person', previous.contactPerson, next.contactPerson);
    add('phone_primary', previous.phonePrimary, next.phonePrimary);
    add('status', previous.status.name, next.status.name);
  }

  Future<void> _seed() async {
    final bundle = buildSeedBundle();
    _companies.addAll(bundle.companies);
    _institutions.addAll(bundle.institutions);
    _programs.addAll(bundle.programs);
    _templates.addAll(bundle.templates);
    for (final company in _companies) {
      _deductionUsed[company.id] = 0;
    }
    for (final seed in bundle.events) {
      _events.add(seed.event);
    }
    for (final seed in bundle.events) {
      switch (seed.finalStatus) {
        case EventStatus.completed:
          await completeEvent(seed.event.id);
          break;
        case EventStatus.cancelled:
          await cancelEvent(seed.event.id);
          break;
        case EventStatus.scheduled:
          break;
      }
    }
    _outbox.clear();
  }
}
