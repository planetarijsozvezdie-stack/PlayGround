import 'package:flutter_test/flutter_test.dart';
import 'package:planetarium_manager/core/contract_pdf.dart';
import 'package:planetarium_manager/core/ru_format.dart';
import 'package:planetarium_manager/data/seed.dart';

void main() {
  testWidgets('договор формируется в PDF с кириллицей', (tester) async {
    await ensureRussianLocale();
    final bundle = buildSeedBundle();
    final company = bundle.companies.first;
    final event = bundle.events.first.event;
    final template = bundle.templates.firstWhere(
      (item) => item.companyId == company.id,
    );

    final bytes = await buildContractPdf(
      company: company,
      event: event,
      templateBody: template.body,
      documentNumber: 'ПЛ-ЛД-Д-2026-0001',
    );

    expect(bytes.length, greaterThan(2000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  testWidgets('акт и счёт формируются в PDF', (tester) async {
    await ensureRussianLocale();
    final bundle = buildSeedBundle();
    final company = bundle.companies.first;
    final event = bundle.events.first.event;

    final act = await buildActPdf(
      company: company,
      event: event,
      documentNumber: 'ПЛ-ЛД-А-2026-0001',
    );
    final invoice = await buildInvoicePdf(
      company: company,
      event: event,
      documentNumber: 'ПЛ-ЛД-С-2026-0001',
    );

    expect(String.fromCharCodes(act.take(4)), '%PDF');
    expect(String.fromCharCodes(invoice.take(4)), '%PDF');
    expect(act.length, greaterThan(2000));
    expect(invoice.length, greaterThan(2000));
  });

  test('все переменные шаблона подставлены', () {
    final bundle = buildSeedBundle();
    final company = bundle.companies.first;
    final event = bundle.events.first.event;
    final template = bundle.templates.firstWhere(
      (item) => item.companyId == company.id,
    );

    final filled = fillTemplate(
      template.body,
      company: company,
      event: event,
      documentNumber: 'ПЛ-ЛД-Д-2026-0001',
      documentDate: DateTime(2026, 10, 21),
    );

    expect(filled.contains('{{'), isFalse);
    expect(filled.contains('ПЛ-ЛД-Д-2026-0001'), isTrue);
    expect(filled.contains(company.name), isTrue);
    expect(filled.contains(event.institutionName), isTrue);
    expect(filled.contains(event.programName), isTrue);
  });
}
