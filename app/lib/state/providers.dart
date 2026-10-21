import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/pin.dart';
import '../services/biometric_service.dart';
import '../data/models.dart';
import '../data/repository.dart';

final repositoryProvider = Provider<Repository>(
  (ref) => throw UnimplementedError('Repository is injected in main()'),
);

class Session {
  const Session({
    required this.loading,
    this.company,
    this.companies = const [],
  });

  final bool loading;
  final Company? company;
  final List<Company> companies;

  Session copyWith({
    bool? loading,
    Company? company,
    bool clearCompany = false,
    List<Company>? companies,
  }) => Session(
    loading: loading ?? this.loading,
    company: clearCompany ? null : (company ?? this.company),
    companies: companies ?? this.companies,
  );
}

class SessionController extends StateNotifier<Session> {
  SessionController(this._repository) : super(const Session(loading: true)) {
    _initialize();
  }

  final Repository _repository;

  Future<void> _initialize() async {
    final companies = await _repository.companies();
    final selectedId = await _repository.selectedCompanyId();
    Company? company;
    for (final candidate in companies) {
      if (candidate.id == selectedId) company = candidate;
    }
    state = Session(loading: false, company: company, companies: companies);
  }

  Future<void> selectCompany(Company company) async {
    await _repository.selectCompany(company.id);
    state = state.copyWith(company: company);
  }

  Future<void> clearCompany() async {
    await _repository.setSetting('selected_company_id', '');
    state = state.copyWith(clearCompany: true);
  }

  Future<void> reload() async {
    state = const Session(loading: true);
    await _initialize();
  }

  Future<void> refreshCompanies() async {
    final companies = await _repository.companies();
    state = state.copyWith(companies: companies);
  }
}

final sessionProvider = StateNotifierProvider<SessionController, Session>(
  (ref) => SessionController(ref.watch(repositoryProvider)),
);

String? _companyId(Ref ref) => ref.watch(sessionProvider).company?.id;

final institutionsProvider = FutureProvider<List<Institution>>((ref) async {
  final id = _companyId(ref);
  if (id == null) return const [];
  return ref.watch(repositoryProvider).institutions(id);
});

final eventsProvider = FutureProvider<List<Event>>((ref) async {
  final id = _companyId(ref);
  if (id == null) return const [];
  return ref.watch(repositoryProvider).events(id);
});

final revenuesProvider = FutureProvider<List<Revenue>>((ref) async {
  final id = _companyId(ref);
  if (id == null) return const [];
  return ref.watch(repositoryProvider).revenues(id);
});

final statsProvider = FutureProvider<DashboardStats>((ref) async {
  final id = _companyId(ref);
  if (id == null) {
    return const DashboardStats(
      completedSessions: 0,
      revenueKopecks: 0,
      plannedEvents: 0,
      taxKopecks: 0,
      deductionRemainingKopecks: 1000000,
    );
  }
  return ref.watch(repositoryProvider).stats(id);
});

final programsProvider = FutureProvider<List<ProgramRecord>>((ref) async {
  final id = _companyId(ref);
  if (id == null) return const [];
  return ref.watch(repositoryProvider).programs(id);
});

final templatesProvider = FutureProvider<List<TemplateRecord>>((ref) async {
  final id = _companyId(ref);
  if (id == null) return const [];
  return ref.watch(repositoryProvider).templates(id);
});

final documentsProvider = FutureProvider<List<DocumentRecord>>((ref) async {
  final id = _companyId(ref);
  if (id == null) return const [];
  return ref.watch(repositoryProvider).documents(id);
});

final outboxProvider = FutureProvider<int>((ref) async {
  return ref.watch(repositoryProvider).pendingOutbox();
});

void invalidateBusinessData(WidgetRef ref) {
  ref.invalidate(institutionsProvider);
  ref.invalidate(eventsProvider);
  ref.invalidate(revenuesProvider);
  ref.invalidate(statsProvider);
  ref.invalidate(programsProvider);
  ref.invalidate(templatesProvider);
  ref.invalidate(documentsProvider);
  ref.invalidate(outboxProvider);
}

final profileNameProvider = FutureProvider<String>((ref) async {
  final name = await ref.watch(repositoryProvider).setting(profileNameKey, '');
  final trimmed = name.trim();
  return trimmed.isEmpty ? 'Марина' : trimmed;
});

class LockState {
  const LockState({
    required this.loading,
    required this.enabled,
    required this.locked,
    this.failedAttempts = 0,
    this.lockedUntil,
  });

  final bool loading;
  final bool enabled;
  final bool locked;
  final int failedAttempts;
  final DateTime? lockedUntil;

  bool get blocked => lockedUntil?.isAfter(DateTime.now()) ?? false;

  LockState copyWith({
    bool? loading,
    bool? enabled,
    bool? locked,
    int? failedAttempts,
    DateTime? lockedUntil,
    bool clearLockedUntil = false,
  }) => LockState(
    loading: loading ?? this.loading,
    enabled: enabled ?? this.enabled,
    locked: locked ?? this.locked,
    failedAttempts: failedAttempts ?? this.failedAttempts,
    lockedUntil: clearLockedUntil ? null : (lockedUntil ?? this.lockedUntil),
  );
}

class LockController extends StateNotifier<LockState> {
  LockController(this._repository)
    : super(const LockState(loading: true, enabled: false, locked: false)) {
    _initialize();
  }

  final Repository _repository;

  Future<void> _initialize() async {
    final enabled = await _pinEnabled();
    final failedAttempts =
        int.tryParse(await _repository.setting(pinFailedAttemptsKey, '0')) ?? 0;
    final untilMs =
        int.tryParse(await _repository.setting(pinLockedUntilKey, '0')) ?? 0;
    final lockedUntil = untilMs > 0
        ? DateTime.fromMillisecondsSinceEpoch(untilMs)
        : null;
    if (lockedUntil != null && !lockedUntil.isAfter(DateTime.now())) {
      await _clearFailures();
    }
    final stillBlocked =
        lockedUntil != null && lockedUntil.isAfter(DateTime.now());
    state = LockState(
      loading: false,
      enabled: enabled,
      locked: enabled,
      failedAttempts: stillBlocked ? failedAttempts : 0,
      lockedUntil: stillBlocked ? lockedUntil : null,
    );
  }

  Future<bool> _pinEnabled() async {
    final hash = await _repository.setting(pinHashKey, '');
    final salt = await _repository.setting(pinSaltKey, '');
    return hash.isNotEmpty && salt.isNotEmpty;
  }

  Future<void> refresh() async {
    final enabled = await _pinEnabled();
    state = LockState(
      loading: false,
      enabled: enabled,
      locked: enabled && state.locked,
    );
  }

  Future<bool> biometricEnabled() async =>
      await _repository.setting(biometricEnabledKey, '0') == '1';

  Future<bool> unlockWithBiometrics() async {
    if (!await biometricEnabled()) return false;
    await _clearFailures();
    state = state.copyWith(
      locked: false,
      failedAttempts: 0,
      clearLockedUntil: true,
    );
    return true;
  }

  Future<void> lockNow() async {
    if (await _pinEnabled()) {
      state = state.copyWith(locked: true);
    }
  }

  Future<bool> unlock(String pin) async {
    final now = DateTime.now();
    final lockedUntil = state.lockedUntil;
    if (lockedUntil?.isAfter(now) ?? false) return false;
    if (lockedUntil != null) {
      await _clearFailures();
      state = state.copyWith(failedAttempts: 0, clearLockedUntil: true);
    }
    final stored = await _storedHash();
    if (stored == null || !await verifyPin(pin, stored)) {
      final attempts = state.failedAttempts + 1;
      DateTime? until;
      if (attempts >= pinHardLockAttempts) {
        until = now.add(pinHardLockDuration);
      } else if (attempts >= pinSoftLockAttempts) {
        until = now.add(pinSoftLockDuration);
      }
      await _saveFailures(attempts, until);
      state = state.copyWith(
        failedAttempts: attempts,
        lockedUntil: until,
        clearLockedUntil: until == null,
      );
      return false;
    }
    await _clearFailures();
    state = state.copyWith(
      locked: false,
      failedAttempts: 0,
      clearLockedUntil: true,
    );
    return true;
  }

  Future<void> _saveFailures(int attempts, DateTime? until) async {
    await _repository.setSetting(pinFailedAttemptsKey, '$attempts');
    await _repository.setSetting(
      pinLockedUntilKey,
      until == null ? '0' : '${until.millisecondsSinceEpoch}',
    );
  }

  Future<void> _clearFailures() async {
    await _repository.setSetting(pinFailedAttemptsKey, '0');
    await _repository.setSetting(pinLockedUntilKey, '0');
  }

  Future<PinHash?> _storedHash() async {
    final hash = await _repository.setting(pinHashKey, '');
    final salt = await _repository.setting(pinSaltKey, '');
    final algorithm = await _repository.setting(
      pinAlgorithmKey,
      pinAlgorithmPbkdf2,
    );
    final defaultIterations = algorithm == pinAlgorithmArgon2id
        ? pinArgon2Iterations
        : pinDefaultIterations;
    final rawIterations = await _repository.setting(
      pinIterationsKey,
      '$defaultIterations',
    );
    final iterations = int.tryParse(rawIterations) ?? defaultIterations;
    if (hash.isEmpty || salt.isEmpty) return null;
    return PinHash(
      hash: hash,
      salt: salt,
      iterations: iterations,
      algorithm: algorithm,
    );
  }
}

final lockProvider = StateNotifierProvider<LockController, LockState>(
  (ref) => LockController(ref.watch(repositoryProvider)),
);
