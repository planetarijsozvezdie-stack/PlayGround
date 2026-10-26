import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ru_format.dart';
import '../data/models.dart';
import '../state/providers.dart';
import '../theme.dart';

Future<void> showCalendarDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _CalendarDialog(),
  );
}

class _CalendarDialog extends ConsumerStatefulWidget {
  const _CalendarDialog();

  @override
  ConsumerState<_CalendarDialog> createState() => _CalendarDialogState();
}

class _CalendarDialogState extends ConsumerState<_CalendarDialog> {
  bool _enabled = false;
  bool _busy = false;
  bool _loading = true;
  DateTime? _lastSync;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = ref.read(calendarServiceProvider);
    final enabled = await service.isEnabled();
    final lastSync = await service.lastSyncAt();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _lastSync = lastSync;
      _loading = false;
    });
    if (enabled) await _sync(silent: true);
  }

  Future<void> _toggle(bool value) async {
    setState(() {
      _busy = true;
      _enabled = value;
      _message = null;
    });
    await ref.read(calendarServiceProvider).setEnabled(value);
    if (value) {
      await _sync();
    } else if (mounted) {
      setState(() => _busy = false);
    }
  }

  Future<void> _sync({bool silent = false}) async {
    final company = ref.read(sessionProvider).company;
    if (company == null) return;
    if (mounted) setState(() => _busy = true);
    final service = ref.read(calendarServiceProvider);
    final result = await service.syncCompany(company.id);
    final lastSync = await service.lastSyncAt();
    if (!mounted) return;
    invalidateBusinessData(ref);
    setState(() {
      _busy = false;
      _lastSync = lastSync;
      if (!silent) {
        _message =
            'Создано: ${result.created} · обновлено: ${result.updated} · '
            'удалено: ${result.removed}';
      }
    });
  }

  Future<void> _simulateDeletion() async {
    final company = ref.read(sessionProvider).company;
    if (company == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final name = await ref
        .read(calendarServiceProvider)
        .simulateRemoteDeletion(company.id);
    final lastSync = await ref.read(calendarServiceProvider).lastSyncAt();
    if (!mounted) return;
    invalidateBusinessData(ref);
    setState(() {
      _busy = false;
      _lastSync = lastSync;
      _message = name == null
          ? 'В календаре пока нет событий для удаления'
          : 'Удалено из демо-Google: $name';
    });
  }

  @override
  Widget build(BuildContext context) {
    final company = ref.watch(sessionProvider).company;
    final events = ref.watch(eventsProvider).valueOrNull ?? const <Event>[];
    final synced = events.where((event) => event.googleEventId != null).length;
    return AlertDialog(
      title: const Text('Google Календарь'),
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
                              'Демо-режим: события сохраняются в фиктивном '
                              'календаре внутри приложения. Реальный Google '
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
                            : 'Календарь: ${company.shortName}',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      synced == 0
                          ? 'В календаре нет событий'
                          : 'Событий в календаре: $synced',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Последняя синхронизация: ${_lastSyncLabel(_lastSync)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: CosmicColors.muted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Выгружаются только мероприятия. Изменения из Google не '
                      'импортируются, но удаление события в Google удалит его '
                      'в приложении.',
                      style: TextStyle(fontSize: 12, color: CosmicColors.muted),
                    ),
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
          onPressed: _busy || synced == 0 || !_enabled
              ? null
              : _simulateDeletion,
          child: const Text('Имитировать удаление'),
        ),
        TextButton(
          onPressed: _busy || !_enabled ? null : () => _sync(),
          child: const Text('Синхронизировать'),
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
