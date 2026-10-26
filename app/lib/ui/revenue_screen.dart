import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../core/company_time.dart';
import '../core/export_data.dart';
import '../core/money.dart';
import '../core/revenue_analytics.dart';
import '../core/revenue_pdf.dart';
import '../core/ru_format.dart';
import '../data/models.dart';
import '../state/providers.dart';
import '../theme.dart';
import 'dialogs.dart';
import 'document_store.dart';
import 'export_action.dart';

class RevenueScreen extends ConsumerWidget {
  const RevenueScreen({super.key, required this.company});

  final Company company;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider).valueOrNull;
    final revenues =
        ref.watch(revenuesProvider).valueOrNull ?? const <Revenue>[];
    final companyTotals =
        ref.watch(companyRevenueTotalsProvider).valueOrNull ??
        const <String, int>{};
    final companies = ref.watch(sessionProvider).companies;
    final today = todayInCompany(company.timezone);
    final months = List.generate(
      6,
      (i) => DateTime(today.year, today.month - 5 + i),
    );
    final totals = months
        .map((month) => revenueTotalForMonth(revenues, month))
        .toList();
    final monthTotal = revenueTotalForMonth(revenues, today);
    final previousMonthTotal = revenueTotalForMonth(
      revenues,
      DateTime(today.year, today.month - 1),
    );
    final yearTotal = revenueTotalForYear(revenues, today);
    final previousYearTotal = revenueTotalForYear(
      revenues,
      DateTime(today.year - 1),
    );
    final todayTotal = revenueTotalOnDay(revenues, today);
    final todayOperations = revenues
        .where((revenue) => isoDate(revenue.date) == isoDate(today))
        .length;
    final daily = revenueDailySeries(revenues, today);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        _RevenueHero(
          revenueKopecks: monthTotal,
          taxKopecks: stats?.taxKopecks ?? 0,
          sessions: stats?.completedSessions ?? 0,
          comparison: _comparisonLabel(
            monthTotal,
            previousMonthTotal,
            'к прошлому месяцу',
          ),
          comparisonColor: monthTotal >= previousMonthTotal
              ? CosmicColors.success
              : CosmicColors.danger,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _PeriodCard(
                label: 'Сегодня',
                value: todayTotal,
                note:
                    '$todayOperations '
                    '${pluralRu(todayOperations, 'операция', 'операции', 'операций')}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PeriodCard(
                label: 'Год',
                value: yearTotal,
                note: _comparisonLabel(
                  yearTotal,
                  previousYearTotal,
                  'к прошлому году',
                ),
                noteColor: yearTotal >= previousYearTotal
                    ? CosmicColors.success
                    : CosmicColors.danger,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          decoration: BoxDecoration(
            color: CosmicColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: CosmicColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Выручка по месяцам',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: CosmicColors.text2,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 140,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _BarChartPainter(
                    values: totals,
                    labels: months.map((m) => _monthShort(m)).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          decoration: BoxDecoration(
            color: CosmicColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: CosmicColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Последние 30 дней',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: CosmicColors.text2,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 110,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _LineChartPainter(
                    values: daily,
                    color: CosmicColors.accent2,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _CompanyRevenueCard(
          companies: companies,
          totals: companyTotals,
          selectedCompanyId: company.id,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: CosmicColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: CosmicColors.warning.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    size: 16,
                    color: CosmicColors.warning,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'НПД за месяц',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: CosmicColors.text2,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatKopecks(stats?.taxKopecks ?? 0),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: CosmicColors.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Остаток вычета: '
                '${formatKopecks(stats?.deductionRemainingKopecks ?? 0)} из '
                '${formatKopecks(1000000)}',
                style: const TextStyle(fontSize: 11, color: CosmicColors.muted),
              ),
              const SizedBox(height: 6),
              const Text(
                'Оценка. Чеки формируются в приложении «Мой налог»; '
                'НПД платится ежемесячно.',
                style: TextStyle(
                  fontSize: 10,
                  color: CosmicColors.muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Text(
              'Операции',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CosmicColors.text2,
              ),
            ),
            const Spacer(),
            PopupMenuButton<String>(
              tooltip: 'Экспорт',
              icon: const Icon(Icons.ios_share, size: 18),
              onSelected: (value) {
                if (value == 'pdf') {
                  unawaited(_openRevenuePdf(context, company, revenues, stats));
                  return;
                }
                if (value == 'share') {
                  unawaited(
                    _shareRevenuePdf(context, company, revenues, stats),
                  );
                  return;
                }
                exportTable(context, revenuesTable(revenues), value);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'pdf', child: Text('PDF-отчёт')),
                PopupMenuItem(value: 'share', child: Text('Поделиться PDF')),
                PopupMenuItem(value: 'xlsx', child: Text('Экспорт XLSX')),
                PopupMenuItem(value: 'csv', child: Text('Экспорт CSV')),
              ],
            ),
            TextButton.icon(
              onPressed: () => showAddRevenueDialog(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Добавить'),
            ),
          ],
        ),
        if (revenues.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                'Пока нет начислений',
                style: TextStyle(color: CosmicColors.muted, fontSize: 12),
              ),
            ),
          )
        else
          for (final revenue in revenues.take(30))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _RevenueRow(revenue: revenue),
            ),
      ],
    );
  }

  static String _monthShort(DateTime month) {
    final name = formatMonthYearRu(month).split(' ').first;
    return name.length >= 3 ? name.substring(0, 3) : name;
  }
}

Future<(Uint8List, String)> _revenuePdfBytes(
  Company company,
  List<Revenue> revenues,
  DashboardStats? stats,
) async {
  final now = todayInCompany(company.timezone);
  final months = List.generate(6, (i) => DateTime(now.year, now.month - 5 + i));
  final bytes = await buildRevenueReportPdf(
    company: company,
    revenues: revenues,
    months: months,
    stats:
        stats ??
        const DashboardStats(
          completedSessions: 0,
          revenueKopecks: 0,
          plannedEvents: 0,
          taxKopecks: 0,
          deductionRemainingKopecks: 1000000,
        ),
    reportDate: now,
  );
  final fileName =
      'Выручка-${company.shortName}-${now.year}-'
      '${now.month.toString().padLeft(2, '0')}.pdf';
  return (bytes, fileName);
}

Future<void> _openRevenuePdf(
  BuildContext context,
  Company company,
  List<Revenue> revenues,
  DashboardStats? stats,
) async {
  try {
    final (bytes, fileName) = await _revenuePdfBytes(company, revenues, stats);
    final path = await saveDocumentBytes(fileName: fileName, bytes: bytes);
    if (path == null) {
      throw StateError('не удалось сохранить файл');
    }
    await openDocument(path);
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Не удалось сформировать PDF-отчёт: $error')),
    );
  }
}

Future<void> _shareRevenuePdf(
  BuildContext context,
  Company company,
  List<Revenue> revenues,
  DashboardStats? stats,
) async {
  try {
    final (bytes, fileName) = await _revenuePdfBytes(company, revenues, stats);
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Не удалось поделиться PDF-отчётом: $error')),
    );
  }
}

class _RevenueHero extends StatelessWidget {
  const _RevenueHero({
    required this.revenueKopecks,
    required this.taxKopecks,
    required this.sessions,
    required this.comparison,
    required this.comparisonColor,
  });

  final int revenueKopecks;
  final int taxKopecks;
  final int sessions;
  final String comparison;
  final Color comparisonColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CosmicColors.success.withValues(alpha: 0.35)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CosmicColors.success.withValues(alpha: 0.16),
            CosmicColors.surface,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ВЫРУЧКА ЗА МЕСЯЦ',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.1,
              color: CosmicColors.success,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatKopecks(revenueKopecks),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _MiniStat(
                label: pluralRu(sessions, 'сеанс', 'сеанса', 'сеансов'),
                value: '$sessions',
              ),
              const SizedBox(width: 18),
              _MiniStat(label: 'налог', value: formatKopecks(taxKopecks)),
              const SizedBox(width: 18),
              _MiniStat(
                label: 'к получению',
                value: formatKopecks(revenueKopecks - taxKopecks),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                revenueKopecks >= 0
                    ? Icons.insights_outlined
                    : Icons.trending_down,
                size: 13,
                color: comparisonColor,
              ),
              const SizedBox(width: 4),
              Text(
                comparison,
                style: TextStyle(fontSize: 10, color: comparisonColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 12, color: CosmicColors.text),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: CosmicColors.muted),
        ),
      ],
    );
  }
}

class _RevenueRow extends StatelessWidget {
  const _RevenueRow({required this.revenue});

  final Revenue revenue;

  @override
  Widget build(BuildContext context) {
    final positive = revenue.amountKopecks >= 0;
    final title = revenue.comment.isNotEmpty
        ? revenue.comment
        : revenue.category == 'session'
        ? 'Сеанс'
        : 'Прочее';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CosmicColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CosmicColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (positive ? CosmicColors.success : CosmicColors.danger)
                  .withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              positive ? Icons.arrow_downward : Icons.arrow_upward,
              size: 17,
              color: positive ? CosmicColors.success : CosmicColors.danger,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatDateRu(revenue.date)} · '
                  '${revenue.amountKopecks < 0
                      ? 'корректировка'
                      : revenue.isReversed
                      ? 'сторнировано'
                      : revenue.isAuto
                      ? 'авто'
                      : 'вручную'}'
                  ' · ${revenue.counterparty.label}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: CosmicColors.muted,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatKopecks(revenue.amountKopecks),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: positive ? CosmicColors.success : CosmicColors.danger,
                ),
              ),
              Text(
                'налог ${formatKopecks(revenue.taxAmountKopecks)}',
                style: const TextStyle(fontSize: 9, color: CosmicColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({required this.values, required this.labels});

  final List<int> values;
  final List<String> labels;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxValue = values.reduce(math.max);
    const labelHeight = 18.0;
    final chartHeight = size.height - labelHeight;
    final slot = size.width / values.length;
    final barWidth = slot * 0.52;

    final baseline = Paint()
      ..color = CosmicColors.line
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, chartHeight),
      Offset(size.width, chartHeight),
      baseline,
    );

    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      final normalized = maxValue == 0 ? 0.0 : value / maxValue;
      final height = (chartHeight - 8) * normalized;
      final left = slot * i + (slot - barWidth) / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, chartHeight - height, barWidth, height),
        const Radius.circular(5),
      );
      final isLast = i == values.length - 1;
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isLast
              ? [CosmicColors.accent2, CosmicColors.accent]
              : [
                  CosmicColors.accent.withValues(alpha: 0.7),
                  CosmicColors.accent.withValues(alpha: 0.25),
                ],
        ).createShader(rect.outerRect);
      canvas.drawRRect(rect, paint);

      final labelPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            fontSize: 9,
            color: isLast ? CosmicColors.accent2 : CosmicColors.muted,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(
        canvas,
        Offset(slot * i + (slot - labelPainter.width) / 2, chartHeight + 5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.labels != labels;
}

String _comparisonLabel(int current, int previous, String suffix) {
  final percent = revenueChangePercent(current, previous);
  if (percent == null) {
    return current == 0
        ? 'нет данных за прошлый период'
        : 'раньше выручки не было';
  }
  final sign = percent > 0 ? '+' : '';
  return '$sign$percent% $suffix';
}

class _PeriodCard extends StatelessWidget {
  const _PeriodCard({
    required this.label,
    required this.value,
    required this.note,
    this.noteColor = CosmicColors.muted,
  });

  final String label;
  final int value;
  final String note;
  final Color noteColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CosmicColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CosmicColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 9,
              letterSpacing: 0.9,
              color: CosmicColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatKopecks(value),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            note,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 9, color: noteColor, height: 1.2),
          ),
        ],
      ),
    );
  }
}

class _CompanyRevenueCard extends StatelessWidget {
  const _CompanyRevenueCard({
    required this.companies,
    required this.totals,
    required this.selectedCompanyId,
  });

  final List<Company> companies;
  final Map<String, int> totals;
  final String selectedCompanyId;

  static const _colors = [
    CosmicColors.accent2,
    CosmicColors.success,
    CosmicColors.warning,
    CosmicColors.danger,
  ];

  @override
  Widget build(BuildContext context) {
    final entries = companies
        .map((company) => (company: company, value: totals[company.id] ?? 0))
        .toList();
    final total = entries.fold(0, (sum, entry) => sum + entry.value);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CosmicColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CosmicColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Выручка по компаниям',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: CosmicColors.text2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'За текущий месяц, ${formatKopecks(total)}',
            style: const TextStyle(fontSize: 10, color: CosmicColors.muted),
          ),
          const SizedBox(height: 12),
          if (total <= 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Нет выручки за этот месяц',
                style: TextStyle(fontSize: 11, color: CosmicColors.muted),
              ),
            )
          else
            Row(
              children: [
                SizedBox(
                  width: 92,
                  height: 92,
                  child: CustomPaint(
                    painter: _PieChartPainter(
                      values: entries.map((entry) => entry.value).toList(),
                      colors: [
                        for (var i = 0; i < entries.length; i++)
                          _colors[i % _colors.length],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    children: [
                      for (var i = 0; i < entries.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _colors[i % _colors.length],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  entries[i].company.shortName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: CosmicColors.text2,
                                    fontWeight:
                                        entries[i].company.id ==
                                            selectedCompanyId
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                              Text(
                                formatKopecks(entries[i].value),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: CosmicColors.text,
                                ),
                              ),
                              const SizedBox(width: 4),
                              SizedBox(
                                width: 32,
                                child: Text(
                                  total == 0
                                      ? ''
                                      : '${(entries[i].value * 100 / total).round()}%',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: CosmicColors.muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PieChartPainter extends CustomPainter {
  const _PieChartPainter({required this.values, required this.colors});

  final List<int> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold(0, (sum, value) => sum + value);
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: size.shortestSide / 2 - 6,
    );
    if (total <= 0) {
      canvas.drawCircle(
        rect.center,
        rect.width / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..color = CosmicColors.line,
      );
      return;
    }
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] <= 0 ? 0.0 : math.pi * 2 * values[i] / total;
      if (sweep <= 0) continue;
      canvas.drawArc(
        rect,
        start,
        sweep,
        true,
        Paint()..color = colors[i % colors.length],
      );
      start += sweep;
    }
    canvas.drawCircle(
      rect.center,
      rect.width / 4.6,
      Paint()..color = CosmicColors.surface,
    );
    final label = TextPainter(
      text: TextSpan(
        text: '₽',
        style: const TextStyle(
          color: CosmicColors.text2,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(
      canvas,
      rect.center - Offset(label.width / 2, label.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.colors != colors;
  }
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter({required this.values, required this.color});

  final List<int> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxValue = values.fold(0, math.max);
    final gridPaint = Paint()
      ..color = CosmicColors.line.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final y = size.height * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    if (maxValue <= 0) return;
    final step = values.length == 1
        ? size.width
        : size.width / (values.length - 1);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = step * i;
      final y = size.height - (values[i] / maxValue) * (size.height - 8) - 2;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.28),
            color.withValues(alpha: 0.02),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    final lastX = step * (values.length - 1);
    final lastY =
        size.height - (values.last / maxValue) * (size.height - 8) - 2;
    canvas.drawCircle(Offset(lastX, lastY), 3.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}
