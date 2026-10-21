import 'package:flutter/material.dart';

import '../core/export_data.dart';
import 'export_store.dart';

Future<void> exportTable(
  BuildContext context,
  ExportTable table,
  String extension,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final bytes = extension == 'csv' ? csvBytes(table) : xlsxBytes(table);
    final fileName = exportFileName(table, extension);
    final path = await saveExportBytes(
      fileName: fileName,
      bytes: bytes,
      mimeType: extension == 'csv'
          ? 'text/csv;charset=utf-8'
          : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          exportsAreDownloads
              ? 'Файл $fileName скачан · ${exportSummary(table)}'
              : 'Сохранено: $path · ${exportSummary(table)}',
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('Не удалось экспортировать: $error')),
    );
  }
}
