import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';

const pinHashKey = 'pin_hash';
const pinSaltKey = 'pin_salt';
const pinIterationsKey = 'pin_iterations';
const pinAlgorithmKey = 'pin_algorithm';
const pinFailedAttemptsKey = 'pin_failed_attempts';
const pinLockedUntilKey = 'pin_locked_until';
const profileNameKey = 'profile_name';

const pinMinLength = 4;
const pinMaxLength = 6;
const pinDefaultIterations = 30000;
const pinAlgorithmArgon2id = 'argon2id';
const pinAlgorithmPbkdf2 = 'pbkdf2-sha256';
const pinArgon2Iterations = 2;
const pinArgon2MemoryKb = 19456;
const pinArgon2Parallelism = 1;
const pinSoftLockAttempts = 5;
const pinHardLockAttempts = 10;
const pinSoftLockDuration = Duration(seconds: 30);
const pinHardLockDuration = Duration(minutes: 5);

class PinHash {
  const PinHash({
    required this.hash,
    required this.salt,
    required this.iterations,
    this.algorithm = pinAlgorithmPbkdf2,
  });

  final String hash;
  final String salt;
  final int iterations;
  final String algorithm;

  bool get needsRehash => algorithm != pinAlgorithmArgon2id;
}

bool isValidPin(String pin) =>
    RegExp('^\\d{$pinMinLength,$pinMaxLength}\$').hasMatch(pin);

Future<PinHash> hashPin(String pin, {String? salt}) async {
  final saltBytes = salt == null ? _randomBytes(16) : base64Decode(salt);
  final derived = await _argon2id(pin, saltBytes);
  return PinHash(
    hash: base64Encode(derived),
    salt: base64Encode(saltBytes),
    iterations: pinArgon2Iterations,
    algorithm: pinAlgorithmArgon2id,
  );
}

PinHash hashPinPbkdf2(
  String pin, {
  String? salt,
  int iterations = pinDefaultIterations,
}) {
  final saltBytes = salt == null ? _randomBytes(16) : base64Decode(salt);
  final derived = _pbkdf2(pin, saltBytes, iterations, 32);
  return PinHash(
    hash: base64Encode(derived),
    salt: base64Encode(saltBytes),
    iterations: iterations,
    algorithm: pinAlgorithmPbkdf2,
  );
}

Future<bool> verifyPin(String pin, PinHash stored) async {
  if (!isValidPin(pin)) return false;
  final salt = base64Decode(stored.salt);
  final derived = stored.algorithm == pinAlgorithmArgon2id
      ? await _argon2id(pin, salt)
      : _pbkdf2(pin, salt, stored.iterations, 32);
  final expected = base64Decode(stored.hash);
  if (derived.length != expected.length) return false;
  var diff = 0;
  for (var i = 0; i < derived.length; i++) {
    diff |= derived[i] ^ expected[i];
  }
  return diff == 0;
}

Future<List<int>> _argon2id(String pin, List<int> salt) async {
  final algorithm = Argon2id(
    parallelism: pinArgon2Parallelism,
    memory: pinArgon2MemoryKb,
    iterations: pinArgon2Iterations,
    hashLength: 32,
  );
  final key = await algorithm.deriveKey(
    secretKey: SecretKey(utf8.encode(pin)),
    nonce: salt,
  );
  return key.extractBytes();
}

Uint8List _pbkdf2(String password, List<int> salt, int iterations, int length) {
  final hmac = crypto.Hmac(crypto.sha256, utf8.encode(password));
  final block = <int>[...salt, 0, 0, 0, 1];
  var u = hmac.convert(block).bytes;
  final result = List<int>.from(u);
  for (var i = 1; i < iterations; i++) {
    u = hmac.convert(u).bytes;
    for (var j = 0; j < result.length; j++) {
      result[j] ^= u[j];
    }
  }
  return Uint8List.fromList(result.sublist(0, length));
}

Uint8List _randomBytes(int length) {
  final random = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(length, (_) => random.nextInt(256)),
  );
}
