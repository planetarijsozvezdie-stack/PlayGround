import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ru_format.dart';
import '../data/models.dart';
import '../services/drive_service.dart';
import '../state/providers.dart';
import '../theme.dart';
import 'document_store.dart';

Future<void> showDriveDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _DriveDialog(),
  );
}

class _DriveDialog extends ConsumerStatefulWidget {
  const _DriveDialog();

  @override
  ConsumerState<_DriveDialog> createState() => _DriveDialogState();
}

class _DriveDialogState extends ConsumerState<_DriveDialog> {
  bool _enabled = false;
  bool _busy = false;
  bool _loading = true;
  DateTime? _lastSync;
  List<DriveFile> _files = const [];
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = ref.read(driveServiceProvider);
    final enabled = await service.isEnabled();
    final lastSync = await service.lastSyncAt();
    final company = ref.read(sessionProvider).company;
    final files = enabled && company != null
        ? await service.listFiles(company)
        : const <DriveFile>[];
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _lastSync = lastSync;
      _files = files;
      _loading = false;
    });
  }

  Future<void> _toggle(bool value) async {
    setState(() {
      _busy = true;
      _enabled = value;
      _message = null;
    });
    await ref.read(driveServiceProvider).setEnabled(value);
    final company = ref.read(sessionProvider).company;
    final files = value && company != null
        ? await ref.read(driveServiceProvider).listFiles(company)
        : const <DriveFile>[];
    if (!mounted) return;
    setState(() {
      _busy = false;
      _files = files;
    });
  }

  Future<void> _uploadDocuments() async {
    final company = ref.read(sessionProvider).company;
    if (company == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final documents =
        ref.read(documentsProvider).valueOrNull ?? const <DocumentRecord>[];
    var uploaded = 0;
    var failed = 0;
    for (final document in documents) {
      final path = document.filePath;
      if (path == null) {
        failed++;
        continue;
      }
      try {
        final bytes = await readDocumentBytes(path);
        await ref
            .read(driveServiceProvider)
            .uploadDocument(company, document, bytes);
        uploaded++;
      } catch (_) {
        failed++;
      }
    }
    final service = ref.read(driveServiceProvider);
    final files = await service.listFiles(company);
    final lastSync = await service.lastSyncAt();
    if (!mounted) return;
    invalidateBusinessData(ref);
    setState(() {
      _busy = false;
      _files = files;
      _lastSync = lastSync;
      _message = uploaded == 0
          ? 'Не удалось выгрузить документы'
          : 'Выгружено: $uploaded'
                '${failed == 0 ? '' : ' · пропущено: $failed'}';
    });
  }

  Future<void> _uploadBackup() async {
    final company = ref.read(sessionProvider).company;
    if (company == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final repository = ref.read(repositoryProvider);
    try {
      final backup = await repository.exportBackup();
      final bytes = utf8.encode(
        const JsonEncoder.withIndent('  ').convert(backup),
      );
      final file = await ref
          .read(driveServiceProvider)
          .uploadBackup(company, bytes);
      final files = await ref.read(driveServiceProvider).listFiles(company);
      final lastSync = await ref.read(driveServiceProvider).lastSyncAt();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _files = files;
        _lastSync = lastSync;
        _message = file == null
            ? 'Синхронизация выключена'
            : 'Копия выгружена: ${file.name}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = 'Не удалось выгрузить копию: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final company = ref.watch(sessionProvider).company;
    final documents =
        ref.watch(documentsProvider).valueOrNull ?? const <DocumentRecord>[];
    final service = ref.read(driveServiceProvider);
    final remoteDocuments = company == null
        ? 0
        : _files
              .where(
                (file) => file.folderPath == service.documentsFolder(company),
              )
              .length;
    final supportsBackup = ref.watch(repositoryProvider).supportsFullBackup;
    return AlertDialog(
      title: const Text('Google Диск'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CosmicColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.science_outlined,
                            size: 18,
                            color: CosmicColors.accent,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Демо-режим: файлы сохраняются в фиктивном '
                              'Диске внутри приложения. Реальный Google '
                              'подключится после настройки OAuth.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _enabled,
                      onChanged: _busy ? null : _toggle,
                      title: const Text('Синхронизация включена'),
                      subtitle: Text(
                        company == null
                            ? ''
                            : 'Папка: ${service.documentsFolder(company)}',
                      ),
                    ),
                    if (_enabled && company != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Локальных документов: ${documents.length} · '
                        'в Диске: $remoteDocuments',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'В демо-Диске файлов: ${_files.length}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Последняя выгрузка: ${_lastSyncLabel(_lastSync)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: CosmicColors.muted,
                        ),
                      ),
                      if (_files.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        for (final file in _files.take(6))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.insert_drive_file_outlined,
                                  size: 16,
                                  color: CosmicColors.muted,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    file.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Text(
                                  '${(file.sizeBytes / 1024).ceil()} КБ',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: CosmicColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_files.length > 6)
                          Text(
                            'и ещё ${_files.length - 6}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: CosmicColors.muted,
                            ),
                          ),
                      ],
                    ],
                    if (_message != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _message!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: CosmicColors.accent,
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy || !_enabled || !supportsBackup
              ? null
              : _uploadBackup,
          child: Tooltip(
            message: supportsBackup
                ? 'Выгрузить резервную копию'
                : 'Доступно на устройстве',
            child: const Text('Копия'),
          ),
        ),
        TextButton(
          onPressed: _busy || !_enabled ? null : _uploadDocuments,
          child: const Text('Документы'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }

  String _lastSyncLabel(DateTime? value) {
    if (value == null) return 'ещё не выполнялась';
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${formatDateShortRu(value)}, $hour:$minute';
  }
}
