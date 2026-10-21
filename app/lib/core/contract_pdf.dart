import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/models.dart';
import 'money.dart';
import 'ru_format.dart';

Future<Uint8List> buildContractPdf({
  required Company company,
  required Event event,
  required String templateBody,
  required String documentNumber,
  DateTime? documentDate,
}) async {
  final (regular, bold) = await _loadFonts();
  final filled = fillTemplate(
    templateBody,
    company: company,
    event: event,
    documentNumber: documentNumber,
    documentDate: documentDate ?? DateTime.now(),
  );

  final document = pw.Document();
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(42, 42, 42, 48),
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          '${company.shortName} · ${formatDateRu(documentDate ?? DateTime.now())}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ),
      build: (context) => [
        pw.Text(
          'ДОГОВОР ВОЗМЕЗДНОГО ОКАЗАНИЯ УСЛУГ',
          style: pw.TextStyle(font: bold, fontSize: 14),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          '№ $documentNumber',
          style: pw.TextStyle(font: bold, fontSize: 11),
        ),
        pw.SizedBox(height: 14),
        pw.Text(
          filled,
          style: pw.TextStyle(font: regular, fontSize: 10.5, lineSpacing: 3),
        ),
      ],
    ),
  );
  return document.save();
}

Future<Uint8List> buildActPdf({
  required Company company,
  required Event event,
  required String documentNumber,
  DateTime? documentDate,
}) async {
  final (regular, bold) = await _loadFonts();
  final date = documentDate ?? DateTime.now();
  final document = pw.Document();
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(42, 42, 42, 48),
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          '${company.shortName} · ${formatDateRu(date)}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ),
      build: (context) => [
        pw.Text(
          'АКТ ОБ ОКАЗАНИИ УСЛУГ',
          style: pw.TextStyle(font: bold, fontSize: 14),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          '№ $documentNumber от ${formatDateRu(date)}',
          style: pw.TextStyle(font: bold, fontSize: 11),
        ),
        pw.SizedBox(height: 14),
        pw.Text(
          'Исполнитель: ${company.name}, ИНН ${company.inn}, '
          'ОГРНИП ${company.ogrnip}.',
          style: pw.TextStyle(font: regular, fontSize: 10.5, lineSpacing: 3),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Заказчик: ${event.institutionName}, '
          '${event.institutionAddress}.',
          style: pw.TextStyle(font: regular, fontSize: 10.5, lineSpacing: 3),
        ),
        pw.SizedBox(height: 14),
        pw.Text(
          'Исполнитель оказал, а Заказчик принял следующие услуги:',
          style: pw.TextStyle(font: regular, fontSize: 10.5, lineSpacing: 3),
        ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: const ['Услуга', 'Дата', 'Детей', 'Цена, ₽', 'Стоимость, ₽'],
          data: [
            [
              event.programName.isEmpty
                  ? 'Выездная программа'
                  : event.programName,
              formatDateRu(event.date),
              event.childrenCount.toString(),
              formatAmount(event.pricePerChildKopecks),
              formatAmount(event.grossKopecks),
            ],
          ],
          headerStyle: pw.TextStyle(font: bold, fontSize: 9),
          cellStyle: pw.TextStyle(font: regular, fontSize: 9),
          cellAlignment: pw.Alignment.centerLeft,
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'Итого: ${formatKopecks(event.grossKopecks)}. '
          'Доля учреждения: ${formatKopecks(event.institutionShareKopecks)} '
          '(${(event.institutionPercentBp / 100).toStringAsFixed(0)}%). '
          'К оплате исполнителю: ${formatKopecks(event.netKopecks)}.',
          style: pw.TextStyle(font: regular, fontSize: 10.5, lineSpacing: 3),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Услуги оказаны в полном объёме. Претензий по объёму, качеству '
          'и срокам оказания услуг Заказчик не имеет.',
          style: pw.TextStyle(font: regular, fontSize: 10.5, lineSpacing: 3),
        ),
        pw.SizedBox(height: 28),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Исполнитель',
                  style: pw.TextStyle(font: bold, fontSize: 10),
                ),
                pw.SizedBox(height: 18),
                pw.Text(
                  company.signer,
                  style: pw.TextStyle(font: regular, fontSize: 10),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Заказчик',
                  style: pw.TextStyle(font: bold, fontSize: 10),
                ),
                pw.SizedBox(height: 18),
                pw.Text(
                  event.contactPerson.isEmpty
                      ? event.institutionName
                      : event.contactPerson,
                  style: pw.TextStyle(font: regular, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
  return document.save();
}

Future<Uint8List> buildInvoicePdf({
  required Company company,
  required Event event,
  required String documentNumber,
  DateTime? documentDate,
}) async {
  final (regular, bold) = await _loadFonts();
  final date = documentDate ?? DateTime.now();
  final document = pw.Document();
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(42, 42, 42, 48),
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          '${company.shortName} · ${formatDateRu(date)}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ),
      build: (context) => [
        pw.Text(
          'СЧЁТ НА ОПЛАТУ',
          style: pw.TextStyle(font: bold, fontSize: 14),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          '№ $documentNumber от ${formatDateRu(date)}',
          style: pw.TextStyle(font: bold, fontSize: 11),
        ),
        pw.SizedBox(height: 14),
        pw.Text(
          'Исполнитель: ${company.name}\n'
          'ИНН ${company.inn} · ОГРНИП ${company.ogrnip}\n'
          '${company.legalAddress}\n'
          '${company.bankDetails}',
          style: pw.TextStyle(font: regular, fontSize: 10, lineSpacing: 3),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'Заказчик: ${event.institutionName}\n'
          '${event.institutionAddress}',
          style: pw.TextStyle(font: regular, fontSize: 10, lineSpacing: 3),
        ),
        pw.SizedBox(height: 14),
        pw.TableHelper.fromTextArray(
          headers: const [
            '№',
            'Наименование услуги',
            'Кол-во',
            'Цена, ₽',
            'Сумма, ₽',
          ],
          data: [
            [
              '1',
              event.programName.isEmpty
                  ? 'Выездная программа'
                  : event.programName,
              '${event.childrenCount} чел.',
              formatAmount(event.pricePerChildKopecks),
              formatAmount(event.grossKopecks),
            ],
          ],
          headerStyle: pw.TextStyle(font: bold, fontSize: 9),
          cellStyle: pw.TextStyle(font: regular, fontSize: 9),
          cellAlignment: pw.Alignment.centerLeft,
        ),
        pw.SizedBox(height: 10),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Итого к оплате: ${formatKopecks(event.grossKopecks)}',
            style: pw.TextStyle(font: bold, fontSize: 11),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Без НДС. Исполнитель применяет налог на профессиональный доход.',
          style: pw.TextStyle(font: regular, fontSize: 9),
        ),
        pw.SizedBox(height: 28),
        pw.Text(
          'Исполнитель: ${company.signer}',
          style: pw.TextStyle(font: regular, fontSize: 10),
        ),
      ],
    ),
  );
  return document.save();
}

Future<(pw.Font, pw.Font)> _loadFonts() async {
  final regular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/DejaVuSans.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'),
  );
  return (regular, bold);
}

String fillTemplate(
  String template, {
  required Company company,
  required Event event,
  required String documentNumber,
  required DateTime documentDate,
}) {
  final variables = <String, String>{
    'document_number': documentNumber,
    'document_date': formatDateRu(documentDate),
    'company_name': company.name,
    'company_city': company.city,
    'company_inn': company.inn,
    'company_ogrnip': company.ogrnip,
    'company_signer': company.signer,
    'institution_name': event.institutionName,
    'institution_contact': event.contactPerson,
    'institution_address': event.institutionAddress,
    'program_name': event.programName,
    'event_date': formatDateRu(event.date),
    'event_time': event.timeStart,
    'children_count': event.childrenCount.toString(),
    'duration': event.durationMinutes.toString(),
    'price': formatAmount(event.pricePerChildKopecks),
    'gross': formatAmount(event.grossKopecks),
    'institution_share': formatAmount(event.institutionShareKopecks),
    'institution_percent': (event.institutionPercentBp / 100).toStringAsFixed(
      0,
    ),
    'net': formatAmount(event.netKopecks),
  };
  var result = template;
  for (final entry in variables.entries) {
    result = result.replaceAll('{{${entry.key}}}', entry.value);
  }
  return result;
}
