import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/backup_data.dart';
import '../state/providers.dart';
import '../state/reminders.dart';
import '../theme.dart';
import 'export_store.dart';

Future<void> showBackupDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _BackupDialog(),
  );
}

class _BackupDialog extends ConsumerStatefulWidget {
  const _BackupDialog();

  @override
  ConsumerState<_BackupDialog> createState() => _BackupDialogState();
}

class _BackupDialogState extends ConsumerState<_BackupDialog> {
  bool _busy = false;
  String? _status;
  String? _error;

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = null;
      _error = null;
    });
    try {
      final backup = await ref.read(repositoryProvider).exportBackup();
      final bytes = utf8.encode(
        const JsonEncoder.withIndent('  ').convert(backup),
      );
      final fileName = backupFileName(DateTime.now());
      final path = await saveExportBytes(
        fileName: fileName,
        bytes: bytes,
        mimeType: 'application/json;charset=utf-8',
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = path == null
            ? 'Сохранение недоступно на этой платформе'
            : 'Копия сохранена: $path';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Не удалось сохранить копию: $error';
      });
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = null;
      _error = null;
    });
    try {
      final files = await FilePicker.pickFiles(
        dialogTitle: 'Восстановление из резервной копии',
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (files.isEmpty) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      final bytes = await files.first.readAsBytes();
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Файл копии повреждён');
      }
      validateBackupPayload(decoded);
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Заменить все данные?'),
          content: const Text(
            'Текущие учреждения, мероприятия, выручка и документы будут '
            'заменены данными из резервной копии. Отменить это нельзя.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: CosmicColors.danger,
              ),
              child: const Text('Восстановить'),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      await ref.read(repositoryProvider).restoreBackup(decoded);
      await ref.read(sessionProvider.notifier).reload();
      invalidateBusinessData(ref);
      unawaited(refreshReminders(ref));
      await ref.read(lockProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Данные восстановлены из резервной копии'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Не удалось восстановить копию: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final supported = ref.read(repositoryProvider).supportsFullBackup;
    return AlertDialog(
      title: const Text('Резервная копия'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!supported) ...[
                const Text(
                  'Полная резервная копия доступна в приложении на устройстве. '
                  'В веб-демо данные хранятся только в памяти и не сохраняются.',
                  style: TextStyle(fontSize: 13, color: CosmicColors.muted),
                ),
                const SizedBox(height: 12),
              ],
              const Text(
                'Копия включает все компании, учреждения, мероприятия, '
                'выручку, документы и настройки. Файл JSON можно хранить '
                'в облаке или перенести на новое устройство.',
                style: TextStyle(fontSize: 13, color: CosmicColors.text2),
              ),
              if (_status != null) ...[
                const SizedBox(height: 12),
                Text(
                  _status!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: CosmicColors.success,
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: CosmicColors.danger,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy || !supported ? null : _restore,
          child: const Text('Восстановить'),
        ),
        FilledButton(
          onPressed: _busy || !supported ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Сохранить копию'),
        ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }
}
