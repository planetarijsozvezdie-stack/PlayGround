import 'dart:typed_data';

import 'document_store_stub.dart'
    if (dart.library.io) 'document_store_io.dart'
    if (dart.library.js_interop) 'document_store_web.dart'
    as impl;

Future<String?> saveDocumentBytes({
  required String fileName,
  required Uint8List bytes,
}) => impl.saveDocumentBytes(fileName: fileName, bytes: bytes);

Future<void> openDocument(String path) => impl.openDocument(path);

Future<Uint8List> readDocumentBytes(String path) =>
    impl.readDocumentBytes(path);
