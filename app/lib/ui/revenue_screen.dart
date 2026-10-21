import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/company_time.dart';
import '../core/export_data.dart';
import '../core/money.dart';
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
    final now = DateTime.now();
    final months = List.generate(
      6,
      (i) => DateTime(now.year, now.month - 5 + i),
    );
    final totals = months
        .map(
          (month) => revenues
              .where((r) => monthKey(r.date) == monthKey(month))
              .fold(0, (sum, r) => sum + r.amountKopecks),
        )
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        _RevenueHero(
          revenueKopecks: stats?.revenueKopecks ?? 0,
          taxKopecks: stats?.taxKopecks ?? 0,
          sessions: stats?.completedSessions ?? 0,
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
                exportTable(context, revenuesTable(revenues), value);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'pdf', child: Text('PDF-отчёт')),
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

Future<void> _openRevenuePdf(
  BuildContext context,
  Company company,
  List<Revenue> revenues,
  DashboardStats? stats,
) async {
  try {
    final now = DateTime.now();
    final months = List.generate(
      6,
      (i) => DateTime(now.year, now.month - 5 + i),
    );
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

class _RevenueHero extends StatelessWidget {
  const _RevenueHero({
    required this.revenueKopecks,
    required this.taxKopecks,
    required this.sessions,
  });

  final int revenueKopecks;
  final int taxKopecks;
  final int sessions;

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
