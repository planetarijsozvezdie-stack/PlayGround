import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as cipher;
import 'package:uuid/uuid.dart';

import '../core/backup_data.dart';
import '../core/company_time.dart';
import '../core/event_rules.dart';
import '../core/ru_format.dart';
import '../core/tax.dart';
import 'models.dart';
import 'repository.dart';
import 'schema.dart';
import 'seed.dart';

const _uuid = Uuid();

class SqliteRepository implements Repository {
  SqliteRepository._(this._db);

  static Future<SqliteRepository> open({String? path}) async {
    final dbPath =
        path ?? p.join(await getDatabasesPath(), 'planetarium_manager.db');
    final db = await openDatabase(
      dbPath,
      version: 1,
      onConfigure: _configure,
      onCreate: _createSchema,
    );
    return _prepare(db);
  }

  static Future<SqliteRepository> openEncrypted({
    required String path,
    required String password,
  }) async {
    final db = await cipher.openDatabase(
      path,
      password: password,
      version: 1,
      onConfigure: _configure,
      onCreate: _createSchema,
    );
    return _prepare(db);
  }

  static Future<void> _configure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> _createSchema(Database db, int version) async {
    for (final statement in schemaStatements) {
      await db.execute(statement);
    }
  }

  static Future<SqliteRepository> _prepare(Database db) async {
    final repository = SqliteRepository._(db);
    await repository._seedIfEmpty();
    return repository;
  }

  final Database _db;

  String _now() => DateTime.now().toUtc().toIso8601String();

  @override
  Future<List<Company>> companies() async {
    final rows = await _db.query(
      'companies',
      where: 'deleted_at IS NULL',
      orderBy: 'sort_order, name',
    );
    return rows.map(_companyFromRow).toList();
  }

  @override
  Future<String?> selectedCompanyId() async {
    final value = await setting('selected_company_id', '');
    return value.isEmpty ? null : value;
  }

  @override
  Future<void> selectCompany(String companyId) =>
      setSetting('selected_company_id', companyId);

  @override
  Future<String> setting(String key, String fallback) async {
    final rows = await _db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return fallback;
    return (rows.first['value'] as String?) ?? fallback;
  }

  @override
  Future<void> setSetting(String key, String value) async {
    await _db.insert('app_settings', {
      'key': key,
      'value': value,
      'updated_at': _now(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<Institution>> institutions(
    String companyId, {
    InstitutionType? type,
  }) async {
    final rows = await _db.query(
      'institutions',
      where: type == null
          ? 'company_id = ? AND deleted_at IS NULL'
          : 'company_id = ? AND type = ? AND deleted_at IS NULL',
      whereArgs: type == null ? [companyId] : [companyId, type.name],
      orderBy: 'name',
    );
    return rows.map(_institutionFromRow).toList();
  }

  @override
  Future<void> saveInstitution(Institution value) async {
    await _db.transaction((txn) async {
      final existing = await _rowById(txn, 'institutions', value.id);
      final now = _now();
      if (existing == null) {
        final map = _institutionToMap(value);
        map['created_at'] = now;
        map['updated_at'] = now;
        map['version'] = 1;
        await txn.insert('institutions', map);
        await _log(txn, 'institutions', value.id, '*', '', 'создано');
      } else {
        final previous = _institutionFromRow(existing);
        final map = _institutionToMap(value);
        map['created_at'] = existing['created_at'];
        map['updated_at'] = now;
        map['version'] = (existing['version'] as int) + 1;
        await txn.update(
          'institutions',
          map,
          where: 'id = ?',
          whereArgs: [value.id],
        );
        await _logInstitutionDiff(txn, previous, value);
      }
      await _enqueue(txn, 'institutions', value.id, 'upsert');
    });
  }

  @override
  Future<void> deleteInstitution(String id) async {
    await _db.transaction((txn) async {
      final now = _now();
      await txn.rawUpdate(
        'UPDATE institutions SET deleted_at = ?, updated_at = ?, version = version + 1 WHERE id = ?',
        [now, now, id],
      );
      await _enqueue(txn, 'institutions', id, 'delete');
    });
  }

  @override
  Future<List<ChangeEntry>> institutionHistory(String institutionId) async {
    final rows = await _db.query(
      'change_log',
      where: 'table_name = ? AND record_id = ?',
      whereArgs: ['institutions', institutionId],
      orderBy: 'changed_at DESC',
      limit: 100,
    );
    return rows
        .map(
          (row) => ChangeEntry(
            field: row['field_name'] as String,
            oldValue: (row['old_value'] as String?) ?? '',
            newValue: (row['new_value'] as String?) ?? '',
            changedAt: DateTime.parse(row['changed_at'] as String),
          ),
        )
        .toList();
  }

  @override
  Future<List<Event>> events(String companyId, {EventStatus? status}) async {
    final rows = await _db.query(
      'events',
      where: status == null
          ? 'company_id = ? AND deleted_at IS NULL'
          : 'company_id = ? AND status = ? AND deleted_at IS NULL',
      whereArgs: status == null ? [companyId] : [companyId, status.name],
      orderBy: 'event_date, time_start',
    );
    return rows.map(_eventFromRow).toList();
  }

  @override
  Future<void> saveEvent(Event value) async {
    await _db.transaction((txn) async {
      final existing = await _rowById(txn, 'events', value.id);
      final now = _now();
      final map = _eventToMap(value);
      if (existing == null) {
        map['created_at'] = now;
        map['updated_at'] = now;
        map['version'] = 1;
        await txn.insert('events', map);
        await _log(txn, 'events', value.id, '*', '', 'создано');
      } else {
        map['status'] = existing['status'];
        map['completed_at'] = existing['completed_at'];
        map['cancelled_at'] = existing['cancelled_at'];
        map['created_at'] = existing['created_at'];
        map['updated_at'] = now;
        map['version'] = (existing['version'] as int) + 1;
        await txn.update('events', map, where: 'id = ?', whereArgs: [value.id]);
        await _log(txn, 'events', value.id, '*', '', 'изменено');
      }
      await _enqueue(txn, 'events', value.id, 'upsert');
    });
  }

  @override
  Future<void> completeEvent(String id) async {
    await _db.transaction((txn) async {
      final event = await _eventById(txn, id);
      if (event == null || event.status != EventStatus.scheduled) return;
      final now = _now();
      await txn.rawUpdate(
        'UPDATE events SET status = ?, completed_at = ?, updated_at = ?, version = version + 1 WHERE id = ?',
        ['completed', now, now, id],
      );
      final mode = RevenueMode.fromDb(
        await _settingTxn(txn, 'revenue_mode', 'auto'),
      );
      if (EventRules.onStatusChange(
            EventStatus.scheduled,
            EventStatus.completed,
            mode: mode,
          ) ==
          RevenueEffect.createAuto) {
        await _createAutoRevenue(txn, event);
      } else {
        await txn.insert('tasks', {
          'id': _uuid.v4(),
          'company_id': event.companyId,
          'event_id': event.id,
          'title': 'Подтвердить выручку: ${event.institutionName}',
          'description': 'Мероприятие ${isoDate(event.date)} завершено.',
          'due_at': now,
          'is_completed': 0,
          'created_at': now,
          'updated_at': now,
          'version': 1,
        });
      }
      await _adjustInstitutionVisits(txn, event, 1);
      await _log(txn, 'events', id, 'status', 'scheduled', 'completed');
      await _enqueue(txn, 'events', id, 'upsert');
    });
  }

  @override
  Future<void> cancelEvent(String id) async {
    await _db.transaction((txn) async {
      final event = await _eventById(txn, id);
      if (event == null || event.status == EventStatus.cancelled) return;
      if (event.status == EventStatus.completed) {
        await _reverseAutoRevenue(txn, event);
        await _adjustInstitutionVisits(txn, event, -1);
      }
      final now = _now();
      await txn.rawUpdate(
        'UPDATE events SET status = ?, cancelled_at = ?, updated_at = ?, version = version + 1 WHERE id = ?',
        ['cancelled', now, now, id],
      );
      await _log(txn, 'events', id, 'status', event.status.name, 'cancelled');
      await _enqueue(txn, 'events', id, 'upsert');
    });
  }

  @override
  Future<void> reopenEvent(String id) async {
    await _db.transaction((txn) async {
      final event = await _eventById(txn, id);
      if (event == null || event.status == EventStatus.scheduled) return;
      if (event.status == EventStatus.completed) {
        await _reverseAutoRevenue(txn, event);
        await _adjustInstitutionVisits(txn, event, -1);
      }
      final now = _now();
      await txn.rawUpdate(
        'UPDATE events SET status = ?, completed_at = NULL, cancelled_at = NULL, updated_at = ?, version = version + 1 WHERE id = ?',
        ['scheduled', now, id],
      );
      await _log(txn, 'events', id, 'status', event.status.name, 'scheduled');
      await _enqueue(txn, 'events', id, 'upsert');
    });
  }

  @override
  Future<void> deleteEvent(String id) async {
    await _db.transaction((txn) async {
      final event = await _eventById(txn, id);
      if (event == null) return;
      if (event.status == EventStatus.completed) {
        await _reverseAutoRevenue(txn, event);
        await _adjustInstitutionVisits(txn, event, -1);
      }
      final now = _now();
      await txn.rawUpdate(
        'UPDATE events SET deleted_at = ?, updated_at = ?, version = version + 1 WHERE id = ?',
        [now, now, id],
      );
      await _enqueue(txn, 'events', id, 'delete');
    });
  }

  @override
  Future<void> restoreEvent(String id) async {
    await _db.transaction((txn) async {
      final now = _now();
      await txn.rawUpdate(
        'UPDATE events SET deleted_at = NULL, updated_at = ?, version = version + 1 WHERE id = ?',
        [now, id],
      );
      await _enqueue(txn, 'events', id, 'upsert');
    });
  }

  @override
  Future<List<Revenue>> revenues(String companyId) async {
    final rows = await _db.query(
      'revenues',
      where: 'company_id = ? AND deleted_at IS NULL',
      whereArgs: [companyId],
      orderBy: 'revenue_date DESC, created_at DESC',
    );
    return rows.map(_revenueFromRow).toList();
  }

  @override
  Future<void> addRevenue(Revenue value) async {
    await _db.transaction((txn) async {
      final used = await _deductionUsed(txn, value.companyId);
      final tax = TaxCalculator.calculate(
        taxBaseKopecks: value.amountKopecks,
        counterparty: value.counterparty,
        deductionRemainingKopecks: TaxCalculator.deductionLimitKopecks - used,
      );
      final now = _now();
      final map = _revenueToMap(value);
      map['tax_rate_bp'] = tax.rateBp;
      map['tax_base_kopecks'] = value.amountKopecks;
      map['tax_deduction_kopecks'] = tax.deductionAppliedKopecks;
      map['tax_amount_kopecks'] = tax.taxAmountKopecks;
      map['created_at'] = now;
      map['updated_at'] = now;
      map['version'] = 1;
      await txn.insert('revenues', map);
      await _setDeductionUsed(
        txn,
        value.companyId,
        used + tax.deductionAppliedKopecks,
      );
      await _enqueue(txn, 'revenues', value.id, 'upsert');
    });
  }

  @override
  Future<DashboardStats> stats(String companyId) async {
    final companyRow = await _rowById(_db, 'companies', companyId);
    final timezone = (companyRow?['timezone'] as String?) ?? 'Europe/Moscow';
    final today = todayInCompany(timezone);
    final key = monthKey(today);
    final sessions =
        Sqflite.firstIntValue(
          await _db.rawQuery(
            'SELECT COUNT(*) FROM events WHERE company_id = ? AND status = ? '
            'AND deleted_at IS NULL AND substr(event_date, 1, 7) = ?',
            [companyId, 'completed', key],
          ),
        ) ??
        0;
    final revenue =
        Sqflite.firstIntValue(
          await _db.rawQuery(
            'SELECT COALESCE(SUM(amount_kopecks), 0) FROM revenues '
            'WHERE company_id = ? AND deleted_at IS NULL '
            'AND substr(revenue_date, 1, 7) = ?',
            [companyId, key],
          ),
        ) ??
        0;
    final tax =
        Sqflite.firstIntValue(
          await _db.rawQuery(
            'SELECT COALESCE(SUM(tax_amount_kopecks), 0) FROM revenues '
            'WHERE company_id = ? AND deleted_at IS NULL '
            'AND substr(revenue_date, 1, 7) = ?',
            [companyId, key],
          ),
        ) ??
        0;
    final planned =
        Sqflite.firstIntValue(
          await _db.rawQuery(
            'SELECT COUNT(*) FROM events WHERE company_id = ? AND status = ? '
            'AND deleted_at IS NULL AND event_date >= ?',
            [companyId, 'scheduled', isoDate(today)],
          ),
        ) ??
        0;
    final used = await _deductionUsed(_db, companyId);
    return DashboardStats(
      completedSessions: sessions,
      revenueKopecks: revenue,
      plannedEvents: planned,
      taxKopecks: tax,
      deductionRemainingKopecks: TaxCalculator.deductionLimitKopecks - used,
    );
  }

  @override
  Future<List<ProgramRecord>> programs(String companyId) async {
    final rows = await _db.query(
      'programs',
      where: 'company_id = ? AND deleted_at IS NULL',
      whereArgs: [companyId],
      orderBy: 'audience, name',
    );
    return rows
        .map(
          (row) => ProgramRecord(
            id: row['id'] as String,
            companyId: row['company_id'] as String,
            name: row['name'] as String,
            description: (row['description'] as String?) ?? '',
            audience: InstitutionType.fromDb(row['audience'] as String),
            ageGroup: (row['age_group'] as String?) ?? '',
            durationMinutes: row['duration_minutes'] as int,
            isActive: (row['is_active'] as int) == 1,
          ),
        )
        .toList();
  }

  @override
  Future<List<TemplateRecord>> templates(String companyId) async {
    final rows = await _db.query(
      'contract_templates',
      where: 'company_id = ? AND deleted_at IS NULL',
      whereArgs: [companyId],
      orderBy: 'type',
    );
    return rows
        .map(
          (row) => TemplateRecord(
            id: row['id'] as String,
            companyId: row['company_id'] as String,
            type: InstitutionType.fromDb(row['type'] as String),
            name: row['name'] as String,
            body: row['template_content'] as String,
          ),
        )
        .toList();
  }

  @override
  Future<void> saveTemplate(TemplateRecord template) async {
    await _db.transaction((txn) async {
      final existing = await _rowById(txn, 'contract_templates', template.id);
      final now = _now();
      if (existing == null) {
        await txn.insert('contract_templates', {
          'id': template.id,
          'company_id': template.companyId,
          'type': template.type.name,
          'name': template.name,
          'template_content': template.body,
          'variables': '[]',
          'is_active': 1,
          'created_at': now,
          'updated_at': now,
          'version': 1,
        });
        await _log(txn, 'contract_templates', template.id, '*', '', 'создано');
      } else {
        final previousBody = existing['template_content'] as String? ?? '';
        await txn.rawUpdate(
          'UPDATE contract_templates SET name = ?, template_content = ?, '
          'updated_at = ?, version = version + 1 WHERE id = ?',
          [template.name, template.body, now, template.id],
        );
        if (previousBody != template.body) {
          await _log(
            txn,
            'contract_templates',
            template.id,
            'template_content',
            previousBody,
            template.body,
          );
        }
      }
      await _enqueue(txn, 'contract_templates', template.id, 'upsert');
    });
  }

  @override
  Future<List<DocumentRecord>> documents(String companyId) async {
    final rows = await _db.query(
      'documents',
      where: 'company_id = ? AND deleted_at IS NULL',
      whereArgs: [companyId],
      orderBy: 'created_at DESC',
    );
    return rows
        .map(
          (row) => DocumentRecord(
            id: row['id'] as String,
            companyId: row['company_id'] as String,
            eventId: row['event_id'] as String?,
            type: row['type'] as String,
            number: row['document_number'] as String,
            title: row['title'] as String,
            filePath: row['file_path'] as String?,
            sizeBytes: row['size_bytes'] as int?,
            createdAt: DateTime.parse(row['created_at'] as String),
            signed: (row['signed'] as int? ?? 0) == 1,
            signedDate: row['signed_date'] == null
                ? null
                : DateTime.parse(row['signed_date'] as String),
            driveFileId: row['drive_file_id'] as String?,
          ),
        )
        .toList();
  }

  @override
  Future<void> addDocument(DocumentRecord value) async {
    await _db.transaction((txn) async {
      final now = _now();
      await txn.insert('documents', {
        'id': value.id,
        'company_id': value.companyId,
        'event_id': value.eventId,
        'type': value.type,
        'document_number': value.number,
        'title': value.title,
        'file_path': value.filePath,
        'size_bytes': value.sizeBytes,
        'drive_file_id': value.driveFileId,
        'signed': 0,
        'created_at': now,
        'updated_at': now,
        'version': 1,
      });
      await _enqueue(txn, 'documents', value.id, 'upsert');
    });
  }

  @override
  Future<void> setDocumentDriveFile(String id, String driveFileId) async {
    await _db.transaction((txn) async {
      final now = _now();
      await txn.rawUpdate(
        'UPDATE documents SET drive_file_id = ?, updated_at = ?, '
        'version = version + 1 WHERE id = ?',
        [driveFileId, now, id],
      );
      await _enqueue(txn, 'documents', id, 'upsert');
    });
  }

  @override
  Future<void> setDocumentSigned(String id, bool signed) async {
    await _db.transaction((txn) async {
      final now = _now();
      await txn.rawUpdate(
        'UPDATE documents SET signed = ?, signed_date = ?, updated_at = ?, '
        'version = version + 1 WHERE id = ?',
        [signed ? 1 : 0, signed ? now : null, now, id],
      );
      await _enqueue(txn, 'documents', id, 'upsert');
    });
  }

  @override
  Future<void> deleteDocument(String id) async {
    await _db.transaction((txn) async {
      await txn.update(
        'documents',
        {'deleted_at': _now(), 'updated_at': _now(), 'version': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _enqueue(txn, 'documents', id, 'delete');
    });
  }

  @override
  Future<int> pendingOutbox() async {
    return Sqflite.firstIntValue(
          await _db.rawQuery('SELECT COUNT(*) FROM outbox'),
        ) ??
        0;
  }

  @override
  @override
  bool get supportsFullBackup => true;

  static const _backupTables = [
    'companies',
    'users',
    'institutions',
    'programs',
    'contract_templates',
    'events',
    'revenues',
    'tax_state',
    'documents',
    'doc_counters',
    'tasks',
    'interactions',
    'mailing_templates',
    'mailings',
    'mailing_recipients',
    'attachments',
    'change_log',
    'outbox',
    'sync_cursors',
    'app_settings',
  ];

  @override
  Future<Map<String, dynamic>> exportBackup() async {
    final tables = <String, List<Map<String, Object?>>>{};
    for (final table in _backupTables) {
      tables[table] = await _db.query(table);
    }
    return buildBackupPayload(tables);
  }

  @override
  Future<void> restoreBackup(Map<String, dynamic> backup) async {
    validateBackupPayload(backup);
    final rawTables = backup['tables'] as Map;
    final tables = <String, List<Map<String, Object?>>>{};
    for (final table in _backupTables) {
      final rows = rawTables[table];
      if (rows == null) continue;
      if (rows is! List) {
        throw FormatException('Повреждён раздел $table');
      }
      tables[table] = [
        for (final row in rows)
          if (row is Map)
            row.map((key, value) => MapEntry(key.toString(), value))
          else
            throw FormatException('Повреждён раздел $table'),
      ];
    }
    await _db.transaction((txn) async {
      await txn.execute('PRAGMA defer_foreign_keys = ON');
      for (final table in _backupTables.reversed) {
        await txn.delete(table);
      }
      for (final table in _backupTables) {
        final rows = tables[table];
        if (rows == null) continue;
        for (final row in rows) {
          await txn.insert(
            table,
            row,
            conflictAlgorithm: ConflictAlgorithm.abort,
          );
        }
      }
      final violations = await txn.rawQuery('PRAGMA foreign_key_check');
      if (violations.isNotEmpty) {
        throw const FormatException(
          'В резервной копии нарушены связи между данными',
        );
      }
    });
  }

  @override
  Future<void> dispose() => _db.close();

  Future<void> _seedIfEmpty() async {
    final count =
        Sqflite.firstIntValue(
          await _db.rawQuery('SELECT COUNT(*) FROM companies'),
        ) ??
        0;
    if (count > 0) return;
    final bundle = buildSeedBundle();
    final now = _now();
    await _db.transaction((txn) async {
      for (final company in bundle.companies) {
        await txn.insert('companies', {
          'id': company.id,
          'name': company.name,
          'short_name': company.shortName,
          'city': company.city,
          'region': company.region,
          'timezone': company.timezone,
          'inn': company.inn,
          'ogrnip': company.ogrnip,
          'legal_address': company.legalAddress,
          'bank_details': company.bankDetails,
          'phone': company.phone,
          'email': company.email,
          'signer': company.signer,
          'accent': company.accentHex,
          'sort_order': company.id == 'c-lunny' ? 1 : 2,
          'is_active': 1,
          'created_at': now,
          'updated_at': now,
        });
        await txn.insert('tax_state', {
          'company_id': company.id,
          'deduction_limit_kopecks': TaxCalculator.deductionLimitKopecks,
          'deduction_used_kopecks': 0,
          'updated_at': now,
        });
      }
      for (final institution in bundle.institutions) {
        final map = _institutionToMap(institution);
        map['created_at'] = now;
        map['updated_at'] = now;
        map['version'] = 1;
        await txn.insert('institutions', map);
      }
      for (final program in bundle.programs) {
        await txn.insert('programs', {
          'id': program.id,
          'company_id': program.companyId,
          'name': program.name,
          'description': program.description,
          'audience': program.audience.name,
          'age_group': program.ageGroup,
          'duration_minutes': program.durationMinutes,
          'is_active': program.isActive ? 1 : 0,
          'created_at': now,
          'updated_at': now,
          'version': 1,
        });
      }
      for (final template in bundle.templates) {
        await txn.insert('contract_templates', {
          'id': template.id,
          'company_id': template.companyId,
          'type': template.type.name,
          'name': template.name,
          'template_content': template.body,
          'variables': '[]',
          'is_active': 1,
          'created_at': now,
          'updated_at': now,
          'version': 1,
        });
      }
      for (final seed in bundle.events) {
        final map = _eventToMap(seed.event);
        map['created_at'] = now;
        map['updated_at'] = now;
        map['version'] = 1;
        await txn.insert('events', map);
      }
    });
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
  }

  Future<Map<String, Object?>?> _rowById(
    DatabaseExecutor db,
    String table,
    String id,
  ) async {
    final rows = await db.query(
      table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Event?> _eventById(DatabaseExecutor db, String id) async {
    final row = await _rowById(db, 'events', id);
    return row == null ? null : _eventFromRow(row);
  }

  Future<String> _settingTxn(
    DatabaseExecutor db,
    String key,
    String fallback,
  ) async {
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return fallback;
    return (rows.first['value'] as String?) ?? fallback;
  }

  Future<int> _deductionUsed(DatabaseExecutor db, String companyId) async {
    final rows = await db.query(
      'tax_state',
      where: 'company_id = ?',
      whereArgs: [companyId],
      limit: 1,
    );
    if (rows.isEmpty) {
      final now = _now();
      await db.insert('tax_state', {
        'company_id': companyId,
        'deduction_limit_kopecks': TaxCalculator.deductionLimitKopecks,
        'deduction_used_kopecks': 0,
        'updated_at': now,
      });
      return 0;
    }
    return rows.first['deduction_used_kopecks'] as int;
  }

  Future<void> _setDeductionUsed(
    DatabaseExecutor db,
    String companyId,
    int used,
  ) async {
    await db.update(
      'tax_state',
      {
        'deduction_used_kopecks': used.clamp(
          0,
          TaxCalculator.deductionLimitKopecks,
        ),
        'updated_at': _now(),
      },
      where: 'company_id = ?',
      whereArgs: [companyId],
    );
  }

  Future<CounterpartyType> _counterpartyFor(
    DatabaseExecutor db,
    Event event,
  ) async {
    if (event.institutionId == null) return CounterpartyType.legal;
    final rows = await db.query(
      'institutions',
      columns: ['counterparty_type'],
      where: 'id = ?',
      whereArgs: [event.institutionId],
      limit: 1,
    );
    if (rows.isEmpty) return CounterpartyType.legal;
    return CounterpartyType.fromDb(
      (rows.first['counterparty_type'] as String?) ?? 'legal',
    );
  }

  Future<void> _createAutoRevenue(DatabaseExecutor txn, Event event) async {
    final active = await txn.query(
      'revenues',
      columns: ['id'],
      where: 'event_id = ? AND is_auto = 1 AND deleted_at IS NULL',
      whereArgs: [event.id],
      limit: 1,
    );
    if (active.isNotEmpty) return;
    final taxBaseMode = TaxBaseMode.fromDb(
      await _settingTxn(txn, 'tax_base', 'received'),
    );
    final base = taxBaseMode == TaxBaseMode.gross
        ? event.grossKopecks
        : event.netKopecks;
    final counterparty = await _counterpartyFor(txn, event);
    final used = await _deductionUsed(txn, event.companyId);
    final tax = TaxCalculator.calculate(
      taxBaseKopecks: base,
      counterparty: counterparty,
      deductionRemainingKopecks: TaxCalculator.deductionLimitKopecks - used,
    );
    final now = _now();
    final revenue = Revenue(
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
    );
    final map = _revenueToMap(revenue);
    map['created_at'] = now;
    map['updated_at'] = now;
    map['version'] = 1;
    await txn.insert('revenues', map);
    await _setDeductionUsed(
      txn,
      event.companyId,
      used + tax.deductionAppliedKopecks,
    );
    await _log(txn, 'revenues', revenue.id, '*', '', 'начислено');
    await _enqueue(txn, 'revenues', revenue.id, 'upsert');
  }

  Future<void> _reverseAutoRevenue(DatabaseExecutor txn, Event event) async {
    final rows = await txn.query(
      'revenues',
      where: 'event_id = ? AND is_auto = 1 AND deleted_at IS NULL',
      whereArgs: [event.id],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final original = _revenueFromRow(rows.first);
    final now = _now();
    await txn.rawUpdate(
      'UPDATE revenues SET is_auto = 0, is_reversed = 1, updated_at = ?, version = version + 1 WHERE id = ?',
      [now, original.id],
    );
    final reversal = Revenue(
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
    );
    final map = _revenueToMap(reversal);
    map['created_at'] = now;
    map['updated_at'] = now;
    map['version'] = 1;
    await txn.insert('revenues', map);
    final used = await _deductionUsed(txn, event.companyId);
    await _setDeductionUsed(
      txn,
      event.companyId,
      used - original.taxDeductionKopecks,
    );
    await _log(txn, 'revenues', original.id, 'is_reversed', '0', '1');
    await _enqueue(txn, 'revenues', reversal.id, 'upsert');
    await _enqueue(txn, 'revenues', original.id, 'upsert');
  }

  Future<void> _adjustInstitutionVisits(
    DatabaseExecutor txn,
    Event event,
    int delta,
  ) async {
    if (event.institutionId == null) return;
    await txn.rawUpdate(
      'UPDATE institutions SET total_visits = MAX(0, total_visits + ?), '
      'last_visit_date = CASE WHEN ? > 0 THEN ? ELSE last_visit_date END, '
      'updated_at = ? WHERE id = ?',
      [delta, delta, isoDate(event.date), _now(), event.institutionId],
    );
  }

  Future<void> _log(
    DatabaseExecutor db,
    String table,
    String recordId,
    String field,
    String oldValue,
    String newValue,
  ) async {
    await db.insert('change_log', {
      'id': _uuid.v4(),
      'table_name': table,
      'record_id': recordId,
      'field_name': field,
      'old_value': oldValue,
      'new_value': newValue,
      'device_id': 'device-local',
      'changed_at': _now(),
    });
  }

  Future<void> _logInstitutionDiff(
    DatabaseExecutor db,
    Institution previous,
    Institution next,
  ) async {
    final fields = <String, (String, String)>{
      '_type': (previous.type.name, next.type.name),
      'number': (previous.number, next.number),
      'name': (previous.name, next.name),
      'city': (previous.city, next.city),
      'district': (previous.district, next.district),
      'address': (previous.address, next.address),
      'contact_person': (previous.contactPerson, next.contactPerson),
      'phone_primary': (previous.phonePrimary, next.phonePrimary),
      'phone_secondary': (previous.phoneSecondary, next.phoneSecondary),
      'email': (previous.email, next.email),
      'status': (previous.status.name, next.status.name),
      'tags': (previous.tags.join(','), next.tags.join(',')),
    };
    for (final entry in fields.entries) {
      if (entry.value.$1 != entry.value.$2) {
        await _log(
          db,
          'institutions',
          next.id,
          entry.key == '_type' ? 'type' : entry.key,
          entry.value.$1,
          entry.value.$2,
        );
      }
    }
  }

  Future<void> _enqueue(
    DatabaseExecutor db,
    String table,
    String id,
    String operation,
  ) async {
    await db.insert('outbox', {
      'id': _uuid.v4(),
      'entity_table': table,
      'entity_id': id,
      'operation': operation,
      'attempts': 0,
      'created_at': _now(),
    });
  }

  Map<String, Object?> _institutionToMap(Institution i) => {
    'id': i.id,
    'company_id': i.companyId,
    'type': i.type.name,
    'number': i.number,
    'name': i.name,
    'city': i.city,
    'district': i.district,
    'address': i.address,
    'contact_person': i.contactPerson,
    'position': i.position,
    'phone_primary': i.phonePrimary,
    'phone_secondary': i.phoneSecondary,
    'email': i.email,
    'website': i.website,
    'groups_count': i.groupsCount,
    'hall_capacity': i.hallCapacity,
    'counterparty_type': i.counterparty.name,
    'notes': i.notes,
    'last_visit_date': i.lastVisitDate == null
        ? null
        : isoDate(i.lastVisitDate!),
    'total_visits': i.totalVisits,
    'status': i.status.name,
    'tags': jsonEncode(i.tags),
    'external_id': i.externalId,
  };

  Map<String, Object?> _eventToMap(Event e) => {
    'id': e.id,
    'company_id': e.companyId,
    'institution_id': e.institutionId,
    'institution_snapshot': e.snapshotJson,
    'event_date': isoDate(e.date),
    'time_start': e.timeStart,
    'duration_minutes': e.durationMinutes,
    'timezone': e.timezone,
    'program_name': e.programName,
    'children_count': e.childrenCount,
    'price_per_child_kopecks': e.pricePerChildKopecks,
    'institution_percent_bp': e.institutionPercentBp,
    'gross_kopecks': e.grossKopecks,
    'institution_share_kopecks': e.institutionShareKopecks,
    'net_kopecks': e.netKopecks,
    'status': e.status.name,
    'notes': e.notes,
    'google_event_id': e.googleEventId,
  };

  Map<String, Object?> _revenueToMap(Revenue r) => {
    'id': r.id,
    'company_id': r.companyId,
    'event_id': r.eventId,
    'revenue_date': isoDate(r.date),
    'amount_kopecks': r.amountKopecks,
    'gross_kopecks': r.grossKopecks,
    'category': r.category,
    'counterparty_type': r.counterparty.name,
    'tax_rate_bp': r.taxRateBp,
    'tax_base_kopecks': r.taxBaseKopecks,
    'tax_deduction_kopecks': r.taxDeductionKopecks,
    'tax_amount_kopecks': r.taxAmountKopecks,
    'is_auto': r.isAuto ? 1 : 0,
    'is_reversed': r.isReversed ? 1 : 0,
    'reversal_of_id': r.reversalOfId,
    'comment': r.comment,
  };

  Company _companyFromRow(Map<String, Object?> row) => Company(
    id: row['id'] as String,
    name: row['name'] as String,
    shortName: row['short_name'] as String,
    city: row['city'] as String,
    region: (row['region'] as String?) ?? '',
    timezone: row['timezone'] as String,
    inn: (row['inn'] as String?) ?? '',
    ogrnip: (row['ogrnip'] as String?) ?? '',
    legalAddress: (row['legal_address'] as String?) ?? '',
    bankDetails: (row['bank_details'] as String?) ?? '',
    phone: (row['phone'] as String?) ?? '',
    email: (row['email'] as String?) ?? '',
    signer: (row['signer'] as String?) ?? '',
    accentHex: (row['accent'] as String?) ?? '#6C63FF',
  );

  Institution _institutionFromRow(Map<String, Object?> row) => Institution(
    id: row['id'] as String,
    companyId: row['company_id'] as String,
    type: InstitutionType.fromDb(row['type'] as String),
    number: (row['number'] as String?) ?? '',
    name: row['name'] as String,
    city: row['city'] as String,
    district: (row['district'] as String?) ?? '',
    address: (row['address'] as String?) ?? '',
    contactPerson: (row['contact_person'] as String?) ?? '',
    position: (row['position'] as String?) ?? '',
    phonePrimary: (row['phone_primary'] as String?) ?? '',
    phoneSecondary: (row['phone_secondary'] as String?) ?? '',
    email: (row['email'] as String?) ?? '',
    website: (row['website'] as String?) ?? '',
    groupsCount: row['groups_count'] as int?,
    hallCapacity: row['hall_capacity'] as int?,
    notes: (row['notes'] as String?) ?? '',
    lastVisitDate: row['last_visit_date'] == null
        ? null
        : DateTime.parse(row['last_visit_date'] as String),
    totalVisits: (row['total_visits'] as int?) ?? 0,
    status: InstitutionStatus.fromDb(row['status'] as String),
    tags: (jsonDecode((row['tags'] as String?) ?? '[]') as List).cast<String>(),
    counterparty: CounterpartyType.fromDb(
      (row['counterparty_type'] as String?) ?? 'legal',
    ),
    externalId: (row['external_id'] as String?) ?? '',
  );

  Event _eventFromRow(Map<String, Object?> row) {
    final snapshot = jsonDecode(
      row['institution_snapshot'] as String,
    ) as Map<String, dynamic>;
    return Event(
      id: row['id'] as String,
      companyId: row['company_id'] as String,
      institutionId: row['institution_id'] as String?,
      institutionName: (snapshot['name'] as String?) ?? '',
      institutionAddress: (snapshot['address'] as String?) ?? '',
      contactPerson: (snapshot['contact'] as String?) ?? '',
      contactPhone: (snapshot['phone'] as String?) ?? '',
      date: dateFromIso(row['event_date'] as String),
      timeStart: row['time_start'] as String,
      durationMinutes: (row['duration_minutes'] as int?) ?? 40,
      timezone: row['timezone'] as String,
      programName: row['program_name'] as String,
      childrenCount: row['children_count'] as int,
      pricePerChildKopecks: row['price_per_child_kopecks'] as int,
      institutionPercentBp: row['institution_percent_bp'] as int,
      grossKopecks: row['gross_kopecks'] as int,
      institutionShareKopecks: row['institution_share_kopecks'] as int,
      netKopecks: row['net_kopecks'] as int,
      status: EventStatus.fromDb(row['status'] as String),
      notes: (row['notes'] as String?) ?? '',
      googleEventId: row['google_event_id'] as String?,
    );
  }

  Revenue _revenueFromRow(Map<String, Object?> row) => Revenue(
    id: row['id'] as String,
    companyId: row['company_id'] as String,
    eventId: row['event_id'] as String?,
    date: dateFromIso(row['revenue_date'] as String),
    amountKopecks: row['amount_kopecks'] as int,
    grossKopecks: row['gross_kopecks'] as int?,
    category: row['category'] as String,
    counterparty: CounterpartyType.fromDb(row['counterparty_type'] as String),
    taxRateBp: row['tax_rate_bp'] as int,
    taxBaseKopecks: row['tax_base_kopecks'] as int,
    taxDeductionKopecks: (row['tax_deduction_kopecks'] as int?) ?? 0,
    taxAmountKopecks: (row['tax_amount_kopecks'] as int?) ?? 0,
    isAuto: (row['is_auto'] as int) == 1,
    isReversed: (row['is_reversed'] as int) == 1,
    reversalOfId: row['reversal_of_id'] as String?,
    comment: (row['comment'] as String?) ?? '',
  );
}
