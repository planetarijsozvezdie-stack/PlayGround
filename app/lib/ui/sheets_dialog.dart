import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ru_format.dart';
import '../services/sheets_service.dart';
import '../state/providers.dart';
import '../theme.dart';

Future<void> showSheetsDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _SheetsDialog(),
  );
}

class _SheetsDialog extends ConsumerStatefulWidget {
  const _SheetsDialog();

  @override
  ConsumerState<_SheetsDialog> createState() => _SheetsDialogState();
}

class _SheetsDialogState extends ConsumerState<_SheetsDialog> {
  bool _enabled = false;
  bool _busy = false;
  bool _loading = true;
  DateTime? _lastSync;
  String? _spreadsheetId;
  List<SheetInfo> _sheets = const [];
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = ref.read(sheetsServiceProvider);
    final enabled = await service.isEnabled();
    final lastSync = await service.lastSyncAt();
    final id = await service.spreadsheetId();
    final company = ref.read(sessionProvider).company;
    final sheets = company == null
        ? <SheetInfo>[]
        : await service.status(company);
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _lastSync = lastSync;
      _spreadsheetId = id;
      _sheets = sheets;
      _loading = false;
    });
  }

  Future<void> _toggle(bool value) async {
    setState(() {
      _busy = true;
      _enabled = value;
      _message = null;
    });
    await ref.read(sheetsServiceProvider).setEnabled(value);
    if (!mounted) return;
    setState(() => _busy = false);
  }

  Future<void> _export() async {
    final company = ref.read(sessionProvider).company;
    if (company == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final service = ref.read(sheetsServiceProvider);
      final sheets = await service.exportAll(company);
      final lastSync = await service.lastSyncAt();
      final id = await service.spreadsheetId();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _sheets = sheets;
        _lastSync = lastSync;
        _spreadsheetId = id;
        _message = 'Выгружено листов: ${sheets.length}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = 'Не удалось выгрузить: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final company = ref.watch(sessionProvider).company;
    final service = ref.read(sheetsServiceProvider);
    return AlertDialog(
      title: const Text('Google Таблицы'),
      content: SizedBox(
        width: 400,
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
                              'Демо-режим: таблица создаётся в фиктивном '
                              'Google Sheets внутри приложения. Реальный '
                              'Google подключится после настройки OAuth.',
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
                            : 'Таблица: ${service.spreadsheetTitle(company)}',
                      ),
                    ),
                    if (company != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _spreadsheetId == null
                            ? 'Таблица ещё не создана'
                            : 'ID: $_spreadsheetId',
                        style: const TextStyle(
                          fontSize: 12,
                          color: CosmicColors.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Последняя выгрузка: ${_lastSyncLabel(_lastSync)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: CosmicColors.muted,
                        ),
                      ),
                      if (_sheets.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        for (final sheet in _sheets)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '${sheet.name}: ${sheet.rowCount} строк',
                              style: const TextStyle(fontSize: 13),
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
          onPressed: _busy || !_enabled ? null : _export,
          child: const Text('Выгрузить всё'),
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
