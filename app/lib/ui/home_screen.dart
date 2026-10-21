import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/company_time.dart';
import '../core/event_rules.dart';
import '../core/money.dart';
import '../core/ru_format.dart';
import '../data/models.dart';
import '../state/providers.dart';
import '../theme.dart';
import 'dialogs.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    super.key,
    required this.company,
    required this.onNavigate,
  });

  final Company company;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventsProvider).valueOrNull ?? const <Event>[];
    final stats = ref.watch(statsProvider).valueOrNull;
    final outbox = ref.watch(outboxProvider).valueOrNull ?? 0;
    final name = ref.watch(profileNameProvider).valueOrNull ?? 'Марина';
    final today = todayInCompany(company.timezone);
    final upcoming = events
        .where(
          (e) => e.status == EventStatus.scheduled && !e.date.isBefore(today),
        )
        .toList();
    final next = upcoming.isEmpty ? null : upcoming.first;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          _greeting(),
          style: const TextStyle(fontSize: 13, color: CosmicColors.muted),
        ),
        const SizedBox(height: 2),
        Text(
          name,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 18),
        _NextEventCard(event: next, onTap: () => onNavigate(1)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: pluralRu(
                  stats?.completedSessions ?? 0,
                  'Сеанс',
                  'Сеанса',
                  'Сеансов',
                ),
                value: '${stats?.completedSessions ?? 0}',
                icon: Icons.play_circle_outline,
                color: CosmicColors.accent2,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                label: 'Выручка',
                value: formatRubles(stats?.revenueKopecks ?? 0),
                icon: Icons.trending_up,
                color: CosmicColors.success,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                label: 'План',
                value: '${stats?.plannedEvents ?? 0}',
                icon: Icons.event_available_outlined,
                color: CosmicColors.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _SectionTitle('Быстрые действия'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _QuickAction(
              icon: Icons.add_circle_outline,
              label: 'Мероприятие',
              onTap: () => showAddEventDialog(context, ref),
            ),
            _QuickAction(
              icon: Icons.add_business_outlined,
              label: 'Учреждение',
              onTap: () => showAddInstitutionDialog(context, ref),
            ),
            _QuickAction(
              icon: Icons.note_add_outlined,
              label: 'Документ',
              onTap: () => onNavigate(3),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _SectionTitle('Ближайшие'),
        const SizedBox(height: 10),
        if (upcoming.length <= 1)
          const _EmptyHint('Других запланированных мероприятий нет')
        else
          for (final event in upcoming.skip(1).take(4))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _MiniEventRow(event: event, onTap: () => onNavigate(1)),
            ),
        if (outbox > 0) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.cloud_upload_outlined,
                size: 16,
                color: CosmicColors.warning,
              ),
              const SizedBox(width: 8),
              Text(
                'В очереди синхронизации: $outbox',
                style: const TextStyle(
                  fontSize: 12,
                  color: CosmicColors.warning,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return 'Доброй ночи';
    if (hour < 12) return 'Доброе утро';
    if (hour < 18) return 'Добрый день';
    return 'Добрый вечер';
  }
}

class _NextEventCard extends StatelessWidget {
  const _NextEventCard({required this.event, required this.onTap});

  final Event? event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (event == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: CosmicColors.line),
          color: CosmicColors.surface,
        ),
        child: const Row(
          children: [
            Icon(Icons.event_busy_outlined, color: CosmicColors.muted),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Нет запланированных мероприятий.\nДобавьте первое — это займёт минуту.',
                style: TextStyle(color: CosmicColors.muted, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }
    final value = event!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: CosmicColors.accent.withValues(alpha: 0.4)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              CosmicColors.accent.withValues(alpha: 0.22),
              CosmicColors.surface,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.rocket_launch_outlined,
                  size: 16,
                  color: CosmicColors.accent2,
                ),
                const SizedBox(width: 6),
                const Text(
                  'БЛИЖАЙШЕЕ',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    color: CosmicColors.accent2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  formatDateRu(value.date),
                  style: const TextStyle(
                    fontSize: 12,
                    color: CosmicColors.text2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value.institutionName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              value.institutionAddress,
              style: const TextStyle(fontSize: 12, color: CosmicColors.muted),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _Pill(
                  icon: Icons.schedule,
                  text: formatTimeRange(value.timeStart, value.durationMinutes),
                ),
                const SizedBox(width: 8),
                _Pill(
                  icon: Icons.groups_outlined,
                  text: childrenCountLabel(value.childrenCount),
                ),
                const SizedBox(width: 8),
                _Pill(
                  icon: Icons.payments_outlined,
                  text: formatRubles(value.grossKopecks),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: CosmicColors.background2.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: CosmicColors.muted),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 11, color: CosmicColors.text2),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

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
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: CosmicColors.muted),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: CosmicColors.text,
        side: const BorderSide(color: CosmicColors.line),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _MiniEventRow extends StatelessWidget {
  const _MiniEventRow({required this.event, required this.onTap});

  final Event event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: CosmicColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CosmicColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 32,
              decoration: BoxDecoration(
                color: CosmicColors.accent,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.institutionName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${formatDateShortRu(event.date)} · ${event.timeStart}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: CosmicColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              formatRubles(event.grossKopecks),
              style: const TextStyle(fontSize: 12, color: CosmicColors.success),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: CosmicColors.text2,
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 12, color: CosmicColors.muted),
    );
  }
}
