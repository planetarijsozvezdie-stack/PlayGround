import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/import_data.dart';
import '../data/models.dart';
import '../services/institution_import_service.dart';
import '../state/providers.dart';
import '../theme.dart';

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
  await showInstitutionTableImport(
    context,
    company: company,
    table: table,
    sourceLabel: file.name,
  );
}

Future<void> showInstitutionTableImport(
  BuildContext context, {
  required Company company,
  required ImportTable table,
  required String sourceLabel,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => ImportInstitutionsDialog(
      company: company,
      table: table,
      sourceLabel: sourceLabel,
    ),
  );
}

class ImportInstitutionsDialog extends ConsumerStatefulWidget {
  const ImportInstitutionsDialog({
    required this.company,
    required this.table,
    required this.sourceLabel,
    super.key,
  });

  final Company company;
  final ImportTable table;
  final String sourceLabel;

  @override
  ConsumerState<ImportInstitutionsDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends ConsumerState<ImportInstitutionsDialog> {
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
    final existing =
        ref.watch(institutionsProvider).valueOrNull ?? const <Institution>[];
    final service = InstitutionImportService(ref.watch(repositoryProvider));
    final preview = service.preview(
      existing: existing,
      parsed: parsed,
      policy: _policy,
    );
    final existingKeys = <String>{};
    for (final institution in existing) {
      final key = institutionDedupeKey(
        type: institution.type,
        number: institution.number,
        city: institution.city,
        name: institution.name,
      );
      if (key.isNotEmpty) existingKeys.add(key);
    }
    String actionFor(InstitutionDraft draft) {
      final exists = existingKeys.contains(draft.dedupeKey);
      if (!exists) return 'новое';
      return switch (_policy) {
        ImportDuplicatePolicy.skip => 'пропуск',
        ImportDuplicatePolicy.update => 'обновление',
        ImportDuplicatePolicy.create => 'дубль',
      };
    }

    int rankFor(InstitutionDraft draft) => switch (actionFor(draft)) {
      'новое' => 0,
      'обновление' => 1,
      'дубль' => 2,
      _ => 3,
    };
    final previewDrafts = [...parsed.drafts]
      ..sort((a, b) => rankFor(a).compareTo(rankFor(b)));

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
                '${widget.sourceLabel} · ${widget.table.rows.length} строк',
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
                'Дифф: новых ${preview.created} · обновлений '
                '${preview.updated} · пропусков ${preview.skipped} · '
                'ошибок ${preview.errors}',
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
              for (final draft in previewDrafts.take(6))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${draft.name} · ${draft.type.label} · '
                    '${draft.city}${draft.number.isEmpty ? '' : ' №${draft.number}'}'
                    ' — ${actionFor(draft)}',
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
    final service = InstitutionImportService(ref.read(repositoryProvider));
    final existing =
        ref.read(institutionsProvider).valueOrNull ?? const <Institution>[];
    try {
      final result = await service.apply(
        company: widget.company,
        existing: existing,
        parsed: parsed,
        policy: _policy,
      );
      invalidateBusinessData(ref);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Импорт завершён: ${result.summary}'
            '${result.errors == 0 ? '' : ', ошибок ${result.errors}'}',
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
