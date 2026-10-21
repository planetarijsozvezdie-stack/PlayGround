import 'dart:typed_data';

import 'export_store_stub.dart'
    if (dart.library.io) 'export_store_io.dart'
    if (dart.library.js_interop) 'export_store_web.dart'
    as impl;

Future<String?> saveExportBytes({
  required String fileName,
  required Uint8List bytes,
  required String mimeType,
}) =>
    impl.saveExportBytes(fileName: fileName, bytes: bytes, mimeType: mimeType);

bool get exportsAreDownloads => impl.exportsAreDownloads;
