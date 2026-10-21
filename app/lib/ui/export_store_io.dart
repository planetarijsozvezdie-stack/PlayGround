import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String?> saveExportBytes({
  required String fileName,
  required Uint8List bytes,
  required String mimeType,
}) async {
  final base = await getApplicationDocumentsDirectory();
  final directory = Directory(p.join(base.path, 'Планетарий', 'Экспорт'));
  await directory.create(recursive: true);
  final file = File(p.join(directory.path, fileName));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

bool get exportsAreDownloads => false;
