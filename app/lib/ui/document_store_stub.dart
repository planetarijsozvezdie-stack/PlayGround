import 'dart:typed_data';

Future<String?> saveDocumentBytes({
  required String fileName,
  required Uint8List bytes,
}) async => null;

Future<Uint8List> readDocumentBytes(String path) async {
  throw StateError('Чтение PDF не поддерживается на этой платформе.');
}

Future<void> openDocument(String path) async {
  throw StateError('Открытие PDF не поддерживается на этой платформе.');
}
