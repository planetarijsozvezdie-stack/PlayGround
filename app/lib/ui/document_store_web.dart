import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

const _prefix = 'web-doc://';

final Map<String, Uint8List> _cache = {};

Future<String?> saveDocumentBytes({
  required String fileName,
  required Uint8List bytes,
}) async {
  _cache[fileName] = Uint8List.fromList(bytes);
  return '$_prefix$fileName';
}

Future<void> openDocument(String path) async {
  if (!path.startsWith(_prefix)) {
    throw StateError('Файл сохранён на другом устройстве.');
  }
  final bytes = _cache[path.substring(_prefix.length)];
  if (bytes == null) {
    throw StateError(
      'В веб-версии PDF доступен только до перезагрузки страницы.',
    );
  }
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  final url = web.URL.createObjectURL(blob);
  web.window.open(url, '_blank');
}
