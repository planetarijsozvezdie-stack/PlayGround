import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/pin.dart';
import '../core/ru_format.dart';
import '../services/biometric_service.dart';
import '../state/providers.dart';
import '../theme.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  bool _biometricEnabled = false;
  bool _biometricBusy = false;
  String? _error;
  Timer? _lockoutTimer;

  @override
  void initState() {
    super.initState();
    _initBiometrics();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncLockoutTimer());
  }

  void _syncLockoutTimer() {
    _lockoutTimer?.cancel();
    final until = ref.read(lockProvider).lockedUntil;
    if (until == null || !until.isAfter(DateTime.now())) return;
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!until.isAfter(DateTime.now())) {
        timer.cancel();
        setState(() => _error = null);
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _initBiometrics() async {
    final enabled = await ref.read(lockProvider.notifier).biometricEnabled();
    if (!enabled || !mounted) return;
    final available = await BiometricService.isAvailable();
    if (!mounted) return;
    setState(() => _biometricEnabled = available);
    if (available) unawaited(_unlockBiometric());
  }

  Future<void> _unlockBiometric({bool showError = false}) async {
    if (_biometricBusy) return;
    setState(() {
      _biometricBusy = true;
      if (showError) _error = null;
    });
    final ok = await BiometricService.authenticate();
    if (!mounted) return;
    if (ok) {
      final unlocked = await ref
          .read(lockProvider.notifier)
          .unlockWithBiometrics();
      if (!mounted) return;
      if (unlocked) {
        setState(() => _biometricBusy = false);
        return;
      }
    }
    setState(() {
      _biometricBusy = false;
      if (showError) _error = 'Отпечаток не подтверждён. Введите PIN';
    });
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_busy) return;
    final pin = _controller.text.trim();
    if (pin.length < 4) {
      setState(() => _error = 'Введите PIN из 4–6 цифр');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await ref.read(lockProvider.notifier).unlock(pin);
    if (!mounted) return;
    final lock = ref.read(lockProvider);
    final attemptsLeft = pinSoftLockAttempts - lock.failedAttempts;
    setState(() {
      _busy = false;
      if (ok) {
        _error = null;
      } else if (lock.blocked) {
        _error = null;
      } else {
        _error =
            'Неверный PIN · осталось $attemptsLeft '
            '${pluralRu(attemptsLeft, 'попытка', 'попытки', 'попыток')}';
      }
    });
    if (!ok) {
      if (lock.blocked) _syncLockoutTimer();
      _controller.clear();
      _controller.selection = const TextSelection.collapsed(offset: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(lockProvider);
    final blocked = lock.blocked;
    final secondsLeft = lock.lockedUntil == null
        ? 0
        : (lock.lockedUntil!.difference(DateTime.now()).inMilliseconds / 1000)
              .ceil();
    final lockoutMessage = blocked
        ? 'Слишком много попыток. Повторите через $secondsLeft с.'
        : null;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.2, -0.4),
            radius: 1.2,
            colors: [Color(0xFF1D2350), CosmicColors.background],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 54,
                    color: CosmicColors.accent2,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Планетарий Менеджер',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Приложение защищено PIN-кодом',
                    style: TextStyle(fontSize: 13, color: CosmicColors.muted),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    obscureText: true,
                    enabled: !_busy && !blocked,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    style: const TextStyle(fontSize: 24, letterSpacing: 12),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText: '• • • •',
                      counterText: '',
                      errorText: lockoutMessage ?? _error,
                    ),
                    onSubmitted: (_) {
                      if (!blocked) _unlock();
                    },
                  ),
                  if (_biometricEnabled) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _biometricBusy
                            ? null
                            : () => _unlockBiometric(showError: true),
                        icon: const Icon(Icons.fingerprint),
                        label: Text(
                          _biometricBusy
                              ? 'Подтверждение…'
                              : 'Войти по отпечатку',
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy || blocked ? null : _unlock,
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Открыть'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
