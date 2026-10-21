import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String?> saveDocumentBytes({
  required String fileName,
  required Uint8List bytes,
}) async {
  final base = await getApplicationDocumentsDirectory();
  final directory = Directory(p.join(base.path, 'Планетарий', 'Документы'));
  await directory.create(recursive: true);
  final file = File(p.join(directory.path, fileName));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<void> openDocument(String path) async {
  if (!await File(path).exists()) {
    throw StateError('Файл не найден. Сформируйте документ повторно.');
  }
  final result = await OpenFilex.open(path);
  if (result.type != ResultType.done) {
    throw StateError(result.message);
  }
}
