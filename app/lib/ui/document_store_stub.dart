import 'dart:typed_data';

Future<String?> saveDocumentBytes({
  required String fileName,
  required Uint8List bytes,
}) async => null;

Future<void> openDocument(String path) async {
  throw StateError('Открытие PDF не поддерживается на этой платформе.');
}
