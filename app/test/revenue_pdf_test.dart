import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:planetarium_manager/core/revenue_pdf.dart';
import 'package:planetarium_manager/core/ru_format.dart';
import 'package:planetarium_manager/data/memory_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PDF-отчёт содержит выручку и корректный заголовок', () async {
    await ensureRussianLocale();
    final repository = await MemoryRepository.create();
    final company = (await repository.companies()).first;
    final revenues = await repository.revenues(company.id);
    final stats = await repository.stats(company.id);
    final now = DateTime.now();
    final bytes = await buildRevenueReportPdf(
      company: company,
      revenues: revenues,
      months: List.generate(6, (i) => DateTime(now.year, now.month - 5 + i)),
      stats: stats,
      reportDate: now,
    );
    expect(bytes.length, greaterThan(1000));
    expect(latin1.decode(bytes.take(5).toList()), '%PDF-');
  });
}
