import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/import_data.dart';
import '../data/models.dart';
import '../state/providers.dart';
import '../theme.dart';

const _uuid = Uuid();

enum ImportDuplicatePolicy { skip, update, create }

Future<void> showInstitutionImport(
  BuildContext context,
  WidgetRef ref,
  Company company,
) async {
  List<PlatformFile> files;
  try {
    files = await FilePicker.pickFiles(
      dialogTitle: 'Импорт учреждений',
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'csv'],
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Не удалось открыть файл: $error')));
    return;
  }
  if (files.isEmpty) return;
  final file = files.first;
  final bytes = await file.readAsBytes();
  final extension = file.extension?.toLowerCase();
  ImportTable table;
  try {
    table = extension == 'xlsx' ? parseXlsxBytes(bytes) : parseCsvBytes(bytes);
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Не удалось прочитать файл: $error')),
    );
    return;
  }
  if (table.headers.isEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('В файле не найдена таблица')));
    return;
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) =>
        _ImportDialog(company: company, table: table, fileName: file.name),
  );
}

class _ImportDialog extends ConsumerStatefulWidget {
  const _ImportDialog({
    required this.company,
    required this.table,
    required this.fileName,
  });

  final Company company;
  final ImportTable table;
  final String fileName;

  @override
  ConsumerState<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends ConsumerState<_ImportDialog> {
  late Map<String, int> _mapping;
  ImportDuplicatePolicy _policy = ImportDuplicatePolicy.skip;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _mapping = guessInstitutionMapping(widget.table.headers);
  }

  @override
  Widget build(BuildContext context) {
    final parsed = parseInstitutions(widget.table, _mapping);
    return AlertDialog(
      title: const Text('Импорт учреждений'),
      content: SizedBox(
        width: 560,
        height: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.fileName} · ${widget.table.rows.length} строк',
                style: const TextStyle(fontSize: 11, color: CosmicColors.muted),
              ),
              const SizedBox(height: 12),
              const Text(
                'Сопоставление колонок',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              for (final field in institutionImportFields)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: DropdownButtonFormField<int>(
                    key: ValueKey('${field.key}-${_mapping[field.key]}'),
                    initialValue: _mapping[field.key] ?? -1,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: field.label),
                    items: [
                      const DropdownMenuItem(
                        value: -1,
                        child: Text('— не импортировать —'),
                      ),
                      for (
                        var index = 0;
                        index < widget.table.headers.length;
                        index++
                      )
                        DropdownMenuItem(
                          value: index,
                          child: Text(
                            widget.table.headers[index].isEmpty
                                ? 'Колонка ${index + 1}'
                                : widget.table.headers[index],
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) => setState(() {
                            if (value == null || value < 0) {
                              _mapping.remove(field.key);
                            } else {
                              _mapping[field.key] = value;
                            }
                          }),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                'Готово к импорту: ${parsed.drafts.length} · '
                'ошибок: ${parsed.errors.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (parsed.errors.isNotEmpty) ...[
                const SizedBox(height: 6),
                for (final error in parsed.errors.take(4))
                  Text(
                    error,
                    style: const TextStyle(
                      fontSize: 10,
                      color: CosmicColors.danger,
                    ),
                  ),
              ],
              const SizedBox(height: 10),
              const Text(
                'Предпросмотр',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              for (final draft in parsed.drafts.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${draft.name} · ${draft.type.label} · '
                    '${draft.city}${draft.number.isEmpty ? '' : ' №${draft.number}'}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: CosmicColors.text2,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ImportDuplicatePolicy>(
                initialValue: _policy,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Если учреждение уже есть',
                ),
                items: const [
                  DropdownMenuItem(
                    value: ImportDuplicatePolicy.skip,
                    child: Text('Пропустить'),
                  ),
                  DropdownMenuItem(
                    value: ImportDuplicatePolicy.update,
                    child: Text('Обновить существующее'),
                  ),
                  DropdownMenuItem(
                    value: ImportDuplicatePolicy.create,
                    child: Text('Создать новое'),
                  ),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(
                        () => _policy = value ?? ImportDuplicatePolicy.skip,
                      ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _busy || parsed.drafts.isEmpty
              ? null
              : () => _import(parsed),
          child: const Text('Импортировать'),
        ),
      ],
    );
  }

  Future<void> _import(ImportParseResult parsed) async {
    setState(() => _busy = true);
    final repository = ref.read(repositoryProvider);
    final existing =
        ref.read(institutionsProvider).valueOrNull ?? const <Institution>[];
    final byKey = <String, Institution>{};
    for (final institution in existing) {
      final key = institutionDedupeKey(
        type: institution.type,
        number: institution.number,
        city: institution.city,
      );
      if (key.isNotEmpty) byKey[key] = institution;
    }
    var created = 0;
    var updated = 0;
    var skipped = 0;
    try {
      for (final draft in parsed.drafts) {
        final current = byKey[draft.dedupeKey];
        if (current != null) {
          if (_policy == ImportDuplicatePolicy.skip) {
            skipped++;
            continue;
          }
          if (_policy == ImportDuplicatePolicy.update) {
            await repository.saveInstitution(
              current.copyWith(
                type: draft.type,
                number: draft.number,
                name: draft.name,
                city: draft.city,
                district: draft.district.isEmpty
                    ? current.district
                    : draft.district,
                address: draft.address.isEmpty
                    ? current.address
                    : draft.address,
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
        await repository.saveInstitution(
          Institution(
            id: _uuid.v4(),
            companyId: widget.company.id,
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
          ),
        );
        created++;
      }
      invalidateBusinessData(ref);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Импорт завершён: создано $created, обновлено $updated, '
            'пропущено $skipped'
            '${parsed.errors.isEmpty ? '' : ', ошибок ${parsed.errors.length}'}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Импорт прерван: $error')));
    }
  }
}
