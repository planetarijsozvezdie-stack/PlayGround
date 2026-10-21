import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/reminders.dart';
import '../services/notification_service.dart';
import '../state/providers.dart';
import '../state/reminders.dart';
import '../theme.dart';
import 'device_platform.dart';

Future<void> showNotificationsDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _NotificationsDialog(),
  );
}

class _NotificationsDialog extends ConsumerStatefulWidget {
  const _NotificationsDialog();

  @override
  ConsumerState<_NotificationsDialog> createState() =>
      _NotificationsDialogState();
}

class _NotificationsDialogState extends ConsumerState<_NotificationsDialog> {
  bool _loading = true;
  bool _enabled = false;
  bool _busy = false;
  int _leadMinutes = defaultNotificationLeadMinutes;
  String? _status;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repository = ref.read(repositoryProvider);
    final enabled =
        await repository.setting(notificationsEnabledKey, '0') == '1';
    final lead =
        int.tryParse(
          await repository.setting(
            notificationLeadKey,
            '$defaultNotificationLeadMinutes',
          ),
        ) ??
        defaultNotificationLeadMinutes;
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _leadMinutes = notificationLeadOptions.contains(lead)
          ? lead
          : defaultNotificationLeadMinutes;
      _loading = false;
    });
  }

  bool get _supported => notificationsSupported;

  Future<void> _setEnabled(bool value) async {
    if (_busy || !_supported) return;
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });
    final repository = ref.read(repositoryProvider);
    if (value) {
      final granted = await NotificationService.requestPermission();
      if (!granted) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = 'Разрешите уведомления в настройках Android';
        });
        return;
      }
      await repository.setSetting(notificationsEnabledKey, '1');
      final count = await syncAllReminders(repository);
      if (!mounted) return;
      setState(() {
        _enabled = true;
        _busy = false;
        _status = count == 0
            ? 'Напоминания включены, но ближайших мероприятий нет'
            : 'Запланировано напоминаний: $count';
      });
    } else {
      await repository.setSetting(notificationsEnabledKey, '0');
      await NotificationService.cancelAll();
      if (!mounted) return;
      setState(() {
        _enabled = false;
        _busy = false;
        _status = 'Напоминания отключены';
      });
    }
  }

  Future<void> _setLead(int minutes) async {
    if (_busy) return;
    setState(() {
      _leadMinutes = minutes;
      _busy = true;
      _status = null;
      _error = null;
    });
    final repository = ref.read(repositoryProvider);
    await repository.setSetting(notificationLeadKey, '$minutes');
    if (_enabled) {
      final count = await syncAllReminders(repository);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'Запланировано напоминаний: $count';
      });
    } else {
      if (!mounted) return;
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Напоминания'),
      content: SizedBox(
        width: 420,
        child: _loading
            ? const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_supported)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Локальные уведомления доступны в приложении на '
                        'устройстве. В веб-демо они не доставляются.',
                        style: TextStyle(
                          fontSize: 13,
                          color: CosmicColors.muted,
                        ),
                      ),
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Напоминать о мероприятиях'),
                    subtitle: const Text(
                      'Уведомление приходит до начала сеанса',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _enabled,
                    onChanged: _busy || !_supported ? null : _setEnabled,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: _leadMinutes,
                    decoration: const InputDecoration(
                      labelText: 'Когда напоминать',
                    ),
                    items: [
                      for (final minutes in notificationLeadOptions)
                        DropdownMenuItem(
                          value: minutes,
                          child: Text(notificationLeadLabel(minutes)),
                        ),
                    ],
                    onChanged: _busy || !_supported
                        ? null
                        : (value) {
                            if (value != null) _setLead(value);
                          },
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
                  const SizedBox(height: 12),
                  const Text(
                    'Время доставки может сдвигаться на несколько минут '
                    'из-за энергосбережения Android.',
                    style: TextStyle(fontSize: 11, color: CosmicColors.muted),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }
}
