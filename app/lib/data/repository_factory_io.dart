import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'repository.dart';
import 'sqlite_repository.dart';

const _databaseKey = 'planetarium_db_key_v1';
const _databaseName = 'planetarium_manager_secure.db';
const _legacyDatabaseName = 'planetarium_manager.db';

Future<Repository> createRepository() async {
  final base = await getDatabasesPath();
  final path = p.join(base, _databaseName);
  final legacyPath = p.join(base, _legacyDatabaseName);
  final key = await _loadOrCreateKey();
  await _migrateIfNeeded(legacyPath: legacyPath, securePath: path, key: key);
  return SqliteRepository.openEncrypted(path: path, password: key);
}

Future<String> _loadOrCreateKey() async {
  const storage = FlutterSecureStorage();
  final stored = await storage.read(key: _databaseKey);
  if (stored != null && stored.isNotEmpty) return stored;
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  final key = base64Encode(bytes);
  await storage.write(key: _databaseKey, value: key);
  return key;
}

Future<void> _migrateIfNeeded({
  required String legacyPath,
  required String securePath,
  required String key,
}) async {
  if (await File(securePath).exists()) {
    if (await databaseExists(legacyPath)) {
      await deleteDatabase(legacyPath);
    }
    return;
  }
  final legacyExists = await databaseExists(legacyPath);
  if (!legacyExists) return;

  final legacy = await SqliteRepository.open(path: legacyPath);
  late final Map<String, dynamic> backup;
  try {
    backup = await legacy.exportBackup();
  } finally {
    await legacy.dispose();
  }

  final tempPath = '$securePath.migrating';
  final tempFile = File(tempPath);
  if (await tempFile.exists()) await tempFile.delete();
  final encrypted = await SqliteRepository.openEncrypted(
    path: tempPath,
    password: key,
  );
  try {
    await encrypted.restoreBackup(backup);
  } catch (_) {
    await encrypted.dispose();
    if (await tempFile.exists()) await tempFile.delete();
    rethrow;
  }
  await encrypted.dispose();
  await tempFile.rename(securePath);
  await deleteDatabase(legacyPath);
}
