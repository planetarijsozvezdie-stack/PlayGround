import 'package:uuid/uuid.dart';

import '../core/import_data.dart';
import '../data/models.dart';
import '../data/repository.dart';

const _uuid = Uuid();

enum ImportDuplicatePolicy { skip, update, create }

class InstitutionImportPreview {
  const InstitutionImportPreview({
    required this.created,
    required this.updated,
    required this.skipped,
    required this.errors,
  });

  final int created;
  final int updated;
  final int skipped;
  final int errors;

  int get total => created + updated + skipped;
}

class InstitutionImportResult {
  const InstitutionImportResult({
    required this.created,
    required this.updated,
    required this.skipped,
    required this.errors,
  });

  final int created;
  final int updated;
  final int skipped;
  final int errors;

  String get summary =>
      'создано $created, обновлено $updated, пропущено $skipped';
}

class InstitutionImportService {
  const InstitutionImportService(this._repository);

  final Repository _repository;

  InstitutionImportPreview preview({
    required List<Institution> existing,
    required ImportParseResult parsed,
    required ImportDuplicatePolicy policy,
  }) {
    final byKey = _byKey(existing);
    var created = 0;
    var updated = 0;
    var skipped = 0;
    for (final draft in parsed.drafts) {
      final match = byKey[draft.dedupeKey];
      if (match == null) {
        created++;
      } else if (policy == ImportDuplicatePolicy.update) {
        updated++;
      } else if (policy == ImportDuplicatePolicy.create) {
        created++;
      } else {
        skipped++;
      }
    }
    return InstitutionImportPreview(
      created: created,
      updated: updated,
      skipped: skipped,
      errors: parsed.errors.length,
    );
  }

  Future<InstitutionImportResult> apply({
    required Company company,
    required List<Institution> existing,
    required ImportParseResult parsed,
    required ImportDuplicatePolicy policy,
  }) async {
    final byKey = _byKey(existing);
    var created = 0;
    var updated = 0;
    var skipped = 0;
    for (final draft in parsed.drafts) {
      final current = byKey[draft.dedupeKey];
      if (current != null) {
        if (policy == ImportDuplicatePolicy.skip) {
          skipped++;
          continue;
        }
        if (policy == ImportDuplicatePolicy.update) {
          await _repository.saveInstitution(
            current.copyWith(
              type: draft.type,
              number: draft.number,
              name: draft.name,
              city: draft.city,
              district: draft.district.isEmpty
                  ? current.district
                  : draft.district,
              address: draft.address.isEmpty ? current.address : draft.address,
              contactPerson: draft.contactPerson.isEmpty
                  ? current.contactPerson
                  : draft.contactPerson,
              phonePrimary: draft.phonePrimary.isEmpty
                  ? current.phonePrimary
                  : draft.phonePrimary,
              email: draft.email.isEmpty ? current.email : draft.email,
              notes: draft.notes.isEmpty ? current.notes : draft.notes,
              status: draft.status,
              counterparty: draft.counterparty,
              tags: draft.tags.isEmpty ? current.tags : draft.tags,
            ),
          );
          updated++;
          continue;
        }
      }
      final institution = Institution(
        id: _uuid.v4(),
        companyId: company.id,
        type: draft.type,
        number: draft.number,
        name: draft.name,
        city: draft.city,
        district: draft.district,
        address: draft.address,
        contactPerson: draft.contactPerson,
        position: '',
        phonePrimary: draft.phonePrimary,
        phoneSecondary: '',
        email: draft.email,
        website: '',
        groupsCount: null,
        hallCapacity: null,
        notes: draft.notes,
        lastVisitDate: null,
        totalVisits: 0,
        status: draft.status,
        tags: draft.tags,
        counterparty: draft.counterparty,
        externalId: '',
      );
      await _repository.saveInstitution(institution);
      byKey[draft.dedupeKey] = institution;
      created++;
    }
    return InstitutionImportResult(
      created: created,
      updated: updated,
      skipped: skipped,
      errors: parsed.errors.length,
    );
  }

  Map<String, Institution> _byKey(List<Institution> existing) {
    final result = <String, Institution>{};
    for (final institution in existing) {
      final key = institutionDedupeKey(
        type: institution.type,
        number: institution.number,
        city: institution.city,
        name: institution.name,
      );
      if (key.isNotEmpty) result[key] = institution;
    }
    return result;
  }
}
