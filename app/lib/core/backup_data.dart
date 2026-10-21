const backupFormat = 'planetarium-manager-backup';
const backupVersion = 1;

String backupFileName(DateTime now) {
  String two(int value) => value.toString().padLeft(2, '0');
  return 'planetarium-backup-'
      '${now.year}-${two(now.month)}-${two(now.day)}-'
      '${two(now.hour)}${two(now.minute)}.json';
}

Map<String, dynamic> buildBackupPayload(
  Map<String, List<Map<String, Object?>>> tables,
) {
  return {
    'format': backupFormat,
    'version': backupVersion,
    'exported_at': DateTime.now().toUtc().toIso8601String(),
    'tables': tables,
  };
}

void validateBackupPayload(Map<String, dynamic> payload) {
  if (payload['format'] != backupFormat) {
    throw const FormatException('Это не файл резервной копии Планетария');
  }
  final version = payload['version'];
  if (version is! int || version != backupVersion) {
    throw FormatException('Неподдерживаемая версия копии: $version');
  }
  if (payload['tables'] is! Map) {
    throw const FormatException('В копии нет данных');
  }
}
