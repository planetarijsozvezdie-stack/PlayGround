import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/pin.dart';
import '../services/biometric_service.dart';
import '../state/providers.dart';
import 'device_platform.dart';
import '../theme.dart';

Future<void> showProfileDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _ProfileDialog(),
  );
}

class _ProfileDialog extends ConsumerStatefulWidget {
  const _ProfileDialog();

  @override
  ConsumerState<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends ConsumerState<_ProfileDialog> {
  final _name = TextEditingController();
  bool _loading = true;
  bool _pinEnabled = false;
  bool _biometricEnabled = false;
  bool _biometricBusy = false;
  String? _biometricError;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repository = ref.read(repositoryProvider);
    final name = await repository.setting(profileNameKey, 'Марина');
    final hash = await repository.setting(pinHashKey, '');
    final biometric = await repository.setting(biometricEnabledKey, '0') == '1';
    if (!mounted) return;
    setState(() {
      _name.text = name.trim().isEmpty ? 'Марина' : name;
      _pinEnabled = hash.isNotEmpty;
      _biometricEnabled = biometric;
      _loading = false;
    });
  }

  Future<void> _saveName() async {
    final name = _name.text.trim();
    await ref
        .read(repositoryProvider)
        .setSetting(profileNameKey, name.isEmpty ? 'Марина' : name);
    ref.invalidate(profileNameProvider);
  }

  Future<void> _configurePin() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _PinSetupDialog(hasPin: _pinEnabled),
    );
    if (changed != true) return;
    await ref.read(lockProvider.notifier).refresh();
    if (!mounted) return;
    setState(() => _pinEnabled = true);
  }

  Future<void> _disablePin() async {
    final disabled = await showDialog<bool>(
      context: context,
      builder: (_) => const _PinDisableDialog(),
    );
    if (disabled != true) return;
    await ref.read(lockProvider.notifier).refresh();
    if (!mounted) return;
    setState(() {
      _pinEnabled = false;
      _biometricEnabled = false;
    });
  }

  Future<void> _toggleBiometrics(bool value) async {
    if (_biometricBusy || !_pinEnabled) return;
    setState(() {
      _biometricBusy = true;
      _biometricError = null;
    });
    if (!value) {
      await ref.read(repositoryProvider).setSetting(biometricEnabledKey, '0');
      if (!mounted) return;
      setState(() {
        _biometricEnabled = false;
        _biometricBusy = false;
      });
      return;
    }
    if (!biometricsSupported) {
      setState(() {
        _biometricError = 'Вход по отпечатку доступен только на Android';
        _biometricBusy = false;
      });
      return;
    }
    if (!await BiometricService.isAvailable()) {
      if (!mounted) return;
      setState(() {
        _biometricError = 'На устройстве не настроен отпечаток';
        _biometricBusy = false;
      });
      return;
    }
    if (!await BiometricService.authenticate()) {
      if (!mounted) return;
      setState(() {
        _biometricError = 'Отпечаток не подтверждён';
        _biometricBusy = false;
      });
      return;
    }
    await ref.read(repositoryProvider).setSetting(biometricEnabledKey, '1');
    if (!mounted) return;
    setState(() {
      _biometricEnabled = true;
      _biometricBusy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Профиль и безопасность'),
      content: SizedBox(
        width: 420,
        child: _loading
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Имя'),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _saveName,
                        child: const Text('Сохранить имя'),
                      ),
                    ),
                    const Divider(height: 20),
                    Row(
                      children: [
                        Icon(
                          _pinEnabled
                              ? Icons.lock_outline
                              : Icons.lock_open_outlined,
                          color: _pinEnabled
                              ? CosmicColors.success
                              : CosmicColors.muted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('PIN-код'),
                              Text(
                                _pinEnabled
                                    ? 'Включён — запрашивается при запуске'
                                    : 'Не включён',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: CosmicColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _configurePin,
                          child: Text(_pinEnabled ? 'Изменить' : 'Установить'),
                        ),
                      ],
                    ),
                    if (_pinEnabled)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Вход по отпечатку'),
                        subtitle: Text(
                          biometricsSupported
                              ? 'Отпечаток можно использовать вместо PIN'
                              : 'Доступен в приложении на Android',
                          style: const TextStyle(fontSize: 12),
                        ),
                        value: _biometricEnabled,
                        onChanged: _biometricBusy || !biometricsSupported
                            ? null
                            : _toggleBiometrics,
                      ),
                    if (_biometricError != null)
                      Text(
                        _biometricError!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: CosmicColors.danger,
                        ),
                      ),
                    if (_pinEnabled)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await ref.read(lockProvider.notifier).lockNow();
                          },
                          child: const Text('Заблокировать сейчас'),
                        ),
                      ),
                    if (_pinEnabled)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _disablePin,
                          style: TextButton.styleFrom(
                            foregroundColor: CosmicColors.danger,
                          ),
                          child: const Text('Отключить PIN'),
                        ),
                      ),
                    const SizedBox(height: 6),
                    const Text(
                      'PIN хранится в виде хеша. База данных шифруется '
                      'SQLCipher, ключ хранится в защищённом хранилище Android.',
                      style: TextStyle(fontSize: 11, color: CosmicColors.muted),
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }
}

class _PinSetupDialog extends ConsumerStatefulWidget {
  const _PinSetupDialog({required this.hasPin});

  final bool hasPin;

  @override
  ConsumerState<_PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends ConsumerState<_PinSetupDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _repeat = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final next = _next.text.trim();
    if (!isValidPin(next)) {
      setState(() => _error = 'PIN должен состоять из 4–6 цифр');
      return;
    }
    if (next != _repeat.text.trim()) {
      setState(() => _error = 'PIN-коды не совпадают');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final repository = ref.read(repositoryProvider);
    if (widget.hasPin) {
      final hash = await repository.setting(pinHashKey, '');
      final salt = await repository.setting(pinSaltKey, '');
      final iterations = int.tryParse(
        await repository.setting(pinIterationsKey, '$pinDefaultIterations'),
      );
      final algorithm = await repository.setting(
        pinAlgorithmKey,
        pinAlgorithmPbkdf2,
      );
      final stored = PinHash(
        hash: hash,
        salt: salt,
        iterations: iterations ?? pinDefaultIterations,
        algorithm: algorithm,
      );
      if (!await verifyPin(_current.text.trim(), stored)) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = 'Текущий PIN неверен';
        });
        return;
      }
    }
    final hashed = await hashPin(next);
    await repository.setSetting(pinHashKey, hashed.hash);
    await repository.setSetting(pinSaltKey, hashed.salt);
    await repository.setSetting(pinIterationsKey, '${hashed.iterations}');
    await repository.setSetting(pinAlgorithmKey, hashed.algorithm);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.hasPin ? 'Изменить PIN' : 'Установить PIN'),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.hasPin) ...[
                TextField(
                  controller: _current,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Текущий PIN',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: _next,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Новый PIN (4–6 цифр)',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _repeat,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Повторите PIN',
                  counterText: '',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
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
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Сохранить'),
        ),
      ],
    );
  }
}

class _PinDisableDialog extends ConsumerStatefulWidget {
  const _PinDisableDialog();

  @override
  ConsumerState<_PinDisableDialog> createState() => _PinDisableDialogState();
}

class _PinDisableDialogState extends ConsumerState<_PinDisableDialog> {
  final _pin = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _disable() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final repository = ref.read(repositoryProvider);
    final algorithm = await repository.setting(
      pinAlgorithmKey,
      pinAlgorithmPbkdf2,
    );
    final stored = PinHash(
      hash: await repository.setting(pinHashKey, ''),
      salt: await repository.setting(pinSaltKey, ''),
      iterations:
          int.tryParse(
            await repository.setting(pinIterationsKey, '$pinDefaultIterations'),
          ) ??
          pinDefaultIterations,
      algorithm: algorithm,
    );
    if (!await verifyPin(_pin.text.trim(), stored)) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Неверный PIN';
      });
      return;
    }
    await repository.setSetting(pinHashKey, '');
    await repository.setSetting(pinSaltKey, '');
    await repository.setSetting(pinIterationsKey, '');
    await repository.setSetting(pinAlgorithmKey, '');
    await repository.setSetting(biometricEnabledKey, '0');
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Отключить PIN'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Введите текущий PIN, чтобы отключить защиту.',
              style: TextStyle(fontSize: 13, color: CosmicColors.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pin,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'PIN',
                counterText: '',
                errorText: _error,
              ),
              onSubmitted: (_) => _disable(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _busy ? null : _disable,
          style: FilledButton.styleFrom(backgroundColor: CosmicColors.danger),
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Отключить'),
        ),
      ],
    );
  }
}
