import '../core/backup_data.dart';
import '../data/models.dart';
import '../data/repository.dart';

const driveSyncEnabledKey = 'google_drive_sync_enabled';
const driveLastSyncKey = 'google_drive_last_sync_ms';

class DriveFile {
  const DriveFile({
    required this.id,
    required this.name,
    required this.folderPath,
    required this.sizeBytes,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String folderPath;
  final int sizeBytes;
  final DateTime createdAt;
}

abstract class DriveGateway {
  Future<void> ensureFolder(String path);

  Future<String> upload({
    required String folderPath,
    required String name,
    required List<int> bytes,
    String? remoteId,
  });

  Future<List<DriveFile>> files(String folderPath);
}

class FakeDriveGateway implements DriveGateway {
  final Map<String, DriveFile> _files = {};
  final Set<String> _folders = {};
  var _counter = 0;

  int get fileCount => _files.length;

  @override
  Future<void> ensureFolder(String path) async {
    _folders.add(path);
  }

  @override
  Future<String> upload({
    required String folderPath,
    required String name,
    required List<int> bytes,
    String? remoteId,
  }) async {
    _folders.add(folderPath);
    final id = remoteId ?? 'demo-drive-${++_counter}';
    _files[id] = DriveFile(
      id: id,
      name: name,
      folderPath: folderPath,
      sizeBytes: bytes.length,
      createdAt: DateTime.now(),
    );
    return id;
  }

  @override
  Future<List<DriveFile>> files(String folderPath) async {
    final result =
        _files.values.where((file) => file.folderPath == folderPath).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }
}

class DriveService {
  DriveService(this._repository, this._gateway);

  final Repository _repository;
  final DriveGateway _gateway;

  String documentsFolder(Company company) =>
      '/Планетарий/${company.shortName}/Документы';

  String backupsFolder(Company company) =>
      '/Планетарий/${company.shortName}/Резервные копии';

  Future<bool> isEnabled() async =>
      await _repository.setting(driveSyncEnabledKey, 'false') == 'true';

  Future<void> setEnabled(bool enabled) =>
      _repository.setSetting(driveSyncEnabledKey, '$enabled');

  Future<DateTime?> lastSyncAt() async {
    final raw = await _repository.setting(driveLastSyncKey, '');
    final millis = int.tryParse(raw);
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> autoUploadDocument(
    Company company,
    DocumentRecord document,
    List<int> bytes,
  ) async {
    if (!await isEnabled()) return;
    try {
      await uploadDocument(company, document, bytes);
    } catch (_) {
      // Сбой выгрузки не должен ломать локальную работу.
    }
  }

  Future<String?> uploadDocument(
    Company company,
    DocumentRecord document,
    List<int> bytes,
  ) async {
    if (!await isEnabled()) return null;
    final folder = documentsFolder(company);
    await _gateway.ensureFolder(folder);
    final id = await _gateway.upload(
      folderPath: folder,
      name: '${document.number}.pdf',
      bytes: bytes,
      remoteId: document.driveFileId,
    );
    await _repository.setDocumentDriveFile(document.id, id);
    await _touch();
    return id;
  }

  Future<DriveFile?> uploadBackup(Company company, List<int> bytes) async {
    if (!await isEnabled()) return null;
    final folder = backupsFolder(company);
    await _gateway.ensureFolder(folder);
    final name = backupFileName(DateTime.now());
    final id = await _gateway.upload(
      folderPath: folder,
      name: name,
      bytes: bytes,
    );
    await _touch();
    return DriveFile(
      id: id,
      name: name,
      folderPath: folder,
      sizeBytes: bytes.length,
      createdAt: DateTime.now(),
    );
  }

  Future<List<DriveFile>> listFiles(Company company) async {
    final documents = await _gateway.files(documentsFolder(company));
    final backups = await _gateway.files(backupsFolder(company));
    return [...documents, ...backups]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> _touch() => _repository.setSetting(
    driveLastSyncKey,
    '${DateTime.now().millisecondsSinceEpoch}',
  );
}
