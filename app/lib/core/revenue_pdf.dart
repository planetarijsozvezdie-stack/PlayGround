import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/models.dart';
import 'company_time.dart';
import 'money.dart';
import 'ru_format.dart';

Future<Uint8List> buildRevenueReportPdf({
  required Company company,
  required List<Revenue> revenues,
  required List<DateTime> months,
  required DashboardStats stats,
  DateTime? reportDate,
}) async {
  final (regular, bold) = await _loadFonts();
  final date = reportDate ?? DateTime.now();
  final totals = [
    for (final month in months)
      revenues
          .where((revenue) => monthKey(revenue.date) == monthKey(month))
          .fold(0, (sum, revenue) => sum + revenue.amountKopecks),
  ];
  final maxTotal = totals.fold(0, (max, value) => value > max ? value : max);
  final operations = [...revenues]..sort((a, b) => b.date.compareTo(a.date));

  final document = pw.Document();
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 44),
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          '${company.shortName} · ${formatDateRu(date)} · '
          'стр. ${context.pageNumber} из ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ),
      build: (context) => [
        pw.Text(
          'ОТЧЁТ О ВЫРУЧКЕ',
          style: pw.TextStyle(font: bold, fontSize: 16),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          '${company.name} · ${formatDateRu(date)}',
          style: pw.TextStyle(font: regular, fontSize: 10),
        ),
        pw.SizedBox(height: 14),
        pw.Row(
          children: [
            _metric(
              'Выручка за месяц',
              formatKopecks(stats.revenueKopecks),
              bold,
              regular,
            ),
            _metric(
              'Завершено сеансов',
              '${stats.completedSessions}',
              bold,
              regular,
            ),
            _metric(
              'НПД за месяц',
              formatKopecks(stats.taxKopecks),
              bold,
              regular,
            ),
            _metric(
              'Остаток вычета',
              formatKopecks(stats.deductionRemainingKopecks),
              bold,
              regular,
            ),
          ],
        ),
        pw.SizedBox(height: 18),
        pw.Text(
          'Выручка по месяцам',
          style: pw.TextStyle(font: bold, fontSize: 12),
        ),
        pw.SizedBox(height: 8),
        for (var i = 0; i < months.length; i++) ...[
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.SizedBox(
                width: 88,
                child: pw.Text(
                  formatMonthYearRu(months[i]),
                  style: pw.TextStyle(font: regular, fontSize: 9),
                ),
              ),
              pw.SizedBox(
                width: 74,
                child: pw.Text(
                  formatKopecks(totals[i]),
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(font: regular, fontSize: 9),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Container(
                width: maxTotal == 0 ? 0 : 170 * totals[i] / maxTotal,
                height: 8,
                color: PdfColors.blue300,
              ),
            ],
          ),
          pw.SizedBox(height: 6),
        ],
        pw.SizedBox(height: 10),
        pw.Text('Операции', style: pw.TextStyle(font: bold, fontSize: 12)),
        pw.SizedBox(height: 6),
        if (operations.isEmpty)
          pw.Text(
            'Нет начислений за период.',
            style: pw.TextStyle(font: regular, fontSize: 10),
          )
        else
          pw.TableHelper.fromTextArray(
            headers: const [
              'Дата',
              'Категория',
              'Контрагент',
              'Сумма, ₽',
              'НПД, ₽',
            ],
            data: [
              for (final revenue in operations.take(60))
                [
                  formatDateRu(revenue.date),
                  revenue.category,
                  revenue.counterparty.label,
                  formatAmount(revenue.amountKopecks),
                  formatAmount(revenue.taxAmountKopecks),
                ],
            ],
            headerStyle: pw.TextStyle(font: bold, fontSize: 8.5),
            cellStyle: pw.TextStyle(font: regular, fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignment: pw.Alignment.centerLeft,
            columnWidths: {
              0: const pw.FlexColumnWidth(1.4),
              1: const pw.FlexColumnWidth(1.4),
              2: const pw.FlexColumnWidth(1.2),
              3: const pw.FlexColumnWidth(1.1),
              4: const pw.FlexColumnWidth(1),
            },
          ),
      ],
    ),
  );
  return document.save();
}

pw.Widget _metric(String label, String value, pw.Font bold, pw.Font regular) {
  return pw.Expanded(
    child: pw.Container(
      margin: const pw.EdgeInsets.only(right: 8),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(font: regular, fontSize: 7.5)),
          pw.SizedBox(height: 3),
          pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 10)),
        ],
      ),
    ),
  );
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
