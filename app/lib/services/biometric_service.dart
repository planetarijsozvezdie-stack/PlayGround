import 'package:local_auth/local_auth.dart';

import '../ui/device_platform.dart';

const biometricEnabledKey = 'biometric_enabled';

class BiometricService {
  BiometricService._();

  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> isAvailable() async {
    if (!biometricsSupported) return false;
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate() async {
    if (!biometricsSupported) return false;
    try {
      return await _auth.authenticate(
        localizedReason: 'Подтвердите вход в Планетарий',
        biometricOnly: true,
        sensitiveTransaction: true,
      );
    } on LocalAuthException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
