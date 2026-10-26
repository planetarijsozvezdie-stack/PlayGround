import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/company_time.dart';
import '../core/event_rules.dart';
import '../core/money.dart';
import '../core/ru_format.dart';
import '../data/models.dart';
import '../state/providers.dart';
import '../state/reminders.dart';
import '../theme.dart';
import 'dialogs.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key, required this.company});

  final Company company;

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

enum _ScheduleView {
  day('день'),
  week('неделя'),
  month('месяц');

  const _ScheduleView(this.label);

  final String label;
}

const String _allInstitutionsValue = '__all__';

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  EventStatus _status = EventStatus.scheduled;
  _ScheduleView _view = _ScheduleView.day;
  late DateTime _selectedDay;
  final Set<String> _hidden = {};
  final _search = TextEditingController();
  String? _institutionId;

  @override
  void initState() {
    super.initState();
    _selectedDay = todayInCompany(widget.company.timezone);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final events = (ref.watch(eventsProvider).valueOrNull ?? const <Event>[])
        .where((e) => !_hidden.contains(e.id))
        .toList();
    final institutions =
        ref.watch(institutionsProvider).valueOrNull ?? const <Institution>[];
    final query = _search.text.trim().toLowerCase();
    final hasPeriodFilter = query.isNotEmpty || _institutionId != null;
    final filtered = events
        .where((e) => e.status == _status)
        .where(
          (e) => _institutionId == null || e.institutionId == _institutionId,
        )
        .where((e) {
          if (query.isEmpty) return true;
          return e.institutionName.toLowerCase().contains(query) ||
              e.institutionAddress.toLowerCase().contains(query) ||
              e.contactPerson.toLowerCase().contains(query) ||
              e.contactPhone.toLowerCase().contains(query) ||
              e.programName.toLowerCase().contains(query) ||
              e.notes.toLowerCase().contains(query);
        })
        .toList(growable: false);
    final monday = _selectedDay.subtract(
      Duration(days: _selectedDay.weekday - 1),
    );
    final days = switch (_view) {
      _ScheduleView.day => [_selectedDay],
      _ScheduleView.week => List.generate(
        7,
        (i) => monday.add(Duration(days: i)),
      ),
      _ScheduleView.month => List.generate(
        DateTime(_selectedDay.year, _selectedDay.month + 1, 0).day,
        (i) => DateTime(_selectedDay.year, _selectedDay.month, i + 1),
      ),
    };

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<EventStatus>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: EventStatus.scheduled,
                      label: Text('План'),
                      icon: Icon(Icons.event_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: EventStatus.completed,
                      label: Text('Завершено'),
                      icon: Icon(Icons.check_circle_outline, size: 16),
                    ),
                    ButtonSegment(
                      value: EventStatus.cancelled,
                      label: Text('Отменено'),
                      icon: Icon(Icons.block_outlined, size: 16),
                    ),
                  ],
                  selected: {_status},
                  onSelectionChanged: (value) =>
                      setState(() => _status = value.first),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Учреждение, программа, контакт',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Очистить',
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  _search.clear();
                                  setState(() {});
                                },
                              ),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    tooltip: 'Фильтр по учреждению',
                    initialValue: _institutionId ?? _allInstitutionsValue,
                    onSelected: (value) => setState(() {
                      _institutionId = value == _allInstitutionsValue
                          ? null
                          : value;
                    }),
                    icon: Icon(
                      Icons.filter_alt_outlined,
                      size: 20,
                      color: _institutionId == null
                          ? CosmicColors.muted
                          : CosmicColors.accent2,
                    ),
                    itemBuilder: (context) => [
                      const PopupMenuItem<String>(
                        value: _allInstitutionsValue,
                        child: Text('Все учреждения'),
                      ),
                      for (final institution in institutions)
                        PopupMenuItem<String>(
                          value: institution.id,
                          child: Text(institution.displayName),
                        ),
                    ],
                  ),
                ],
              ),
              if (_institutionId != null) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    label: Text(
                      institutions
                              .where((i) => i.id == _institutionId)
                              .map((i) => i.displayName)
                              .firstOrNull ??
                          'Учреждение',
                    ),
                    onDeleted: () => setState(() => _institutionId = null),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    onPressed: () => _shift(-1),
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Назад',
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: _pickDay,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          children: [
                            Text(
                              switch (_view) {
                                _ScheduleView.day => formatDateRu(_selectedDay),
                                _ScheduleView.week =>
                                  '${formatDateShortRu(days.first)} — '
                                      '${formatDateShortRu(days.last)}',
                                _ScheduleView.month => formatMonthYearRu(
                                  _selectedDay,
                                ),
                              },
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _view.label,
                              style: const TextStyle(
                                fontSize: 11,
                                color: CosmicColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _shift(1),
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Вперёд',
                  ),
                  PopupMenuButton<_ScheduleView>(
                    tooltip: 'Вид',
                    initialValue: _view,
                    onSelected: (value) => setState(() => _view = value),
                    icon: Icon(switch (_view) {
                      _ScheduleView.day => Icons.view_day_outlined,
                      _ScheduleView.week => Icons.view_week_outlined,
                      _ScheduleView.month => Icons.calendar_view_month,
                    }, color: CosmicColors.accent2),
                    itemBuilder: (context) => [
                      for (final view in _ScheduleView.values)
                        PopupMenuItem(value: view, child: Text(view.label)),
                    ],
                  ),
                ],
              ),
              if (_view != _ScheduleView.month)
                SizedBox(
                  height: 58,
                  child: Row(
                    children: [
                      for (final day in days)
                        Expanded(
                          child: _DayChip(
                            day: day,
                            selected: _sameDay(day, _selectedDay),
                            hasEvents: filtered.any(
                              (e) => _sameDay(e.date, day),
                            ),
                            onTap: () => setState(() => _selectedDay = day),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
            ],
          ),
        ),
        Expanded(child: _buildList(filtered, days, hasPeriodFilter)),
      ],
    );
  }

  Widget _buildList(
    List<Event> filtered,
    List<DateTime> periodDays,
    bool hasPeriodFilter,
  ) {
    final items = <Widget>[];
    if (_view != _ScheduleView.day) {
      for (final day in periodDays) {
        final dayEvents = filtered.where((e) => _sameDay(e.date, day)).toList();
        if (dayEvents.isEmpty) continue;
        items.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Text(
              '${formatDateRu(day)} · ${dayEvents.length}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: CosmicColors.text2,
              ),
            ),
          ),
        );
        for (final event in dayEvents) {
          items.add(_card(event));
        }
      }
    } else {
      final dayEvents = filtered
          .where((e) => _sameDay(e.date, _selectedDay))
          .toList();
      for (final event in dayEvents) {
        items.add(_card(event));
      }
    }

    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 40),
          Icon(
            _status == EventStatus.scheduled
                ? Icons.event_available_outlined
                : Icons.inbox_outlined,
            size: 44,
            color: CosmicColors.muted,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              hasPeriodFilter
                  ? 'Ничего не найдено. Измените поиск или фильтр.'
                  : 'Нет мероприятий в этом периоде',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: CosmicColors.muted.withValues(alpha: 0.9),
                fontSize: 13,
              ),
            ),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
      children: items,
    );
  }

  Widget _card(Event event) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey(event.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: CosmicColors.danger.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.delete_outline, color: CosmicColors.danger),
        ),
        confirmDismiss: (_) => _confirmDelete(),
        onDismissed: (_) => _delete(event),
        child: _EventCard(
          event: event,
          onTap: () => showAddEventDialog(context, ref, event: event),
          onAction: (action) => _handleAction(event, action),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить мероприятие?'),
        content: const Text(
          'Запись исчезнет из расписания. Действие можно отменить сразу после удаления.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: CosmicColors.danger),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _delete(Event event) async {
    setState(() => _hidden.add(event.id));
    await ref.read(repositoryProvider).deleteEvent(event.id);
    unawaited(ref.read(calendarServiceProvider).autoRemoveEvent(event));
    invalidateBusinessData(ref);
    unawaited(refreshReminders(ref));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Удалено: ${event.institutionName}'),
        action: SnackBarAction(
          label: 'Вернуть',
          onPressed: () async {
            await ref.read(repositoryProvider).restoreEvent(event.id);
            unawaited(ref.read(calendarServiceProvider).autoSyncEvent(event));
            if (!mounted) return;
            setState(() => _hidden.remove(event.id));
            invalidateBusinessData(ref);
            unawaited(refreshReminders(ref));
          },
        ),
      ),
    );
  }

  Future<void> _handleAction(Event event, String action) async {
    final repository = ref.read(repositoryProvider);
    final calendar = ref.read(calendarServiceProvider);
    Event? updated;
    switch (action) {
      case 'complete':
        await repository.completeEvent(event.id);
        updated = event.copyWith(status: EventStatus.completed);
      case 'cancel':
        await repository.cancelEvent(event.id);
        updated = event.copyWith(status: EventStatus.cancelled);
      case 'reopen':
        await repository.reopenEvent(event.id);
        updated = event.copyWith(status: EventStatus.scheduled);
      case 'edit':
        await showAddEventDialog(context, ref, event: event);
        return;
      case 'delete':
        final confirmed = await _confirmDelete();
        if (confirmed) await _delete(event);
        return;
    }
    if (updated != null) unawaited(calendar.autoSyncEvent(updated));
    invalidateBusinessData(ref);
    unawaited(refreshReminders(ref));
  }

  void _shift(int direction) {
    setState(() {
      _selectedDay = switch (_view) {
        _ScheduleView.day => _selectedDay.add(Duration(days: direction)),
        _ScheduleView.week => _selectedDay.add(Duration(days: 7 * direction)),
        _ScheduleView.month => DateTime(
          _selectedDay.year,
          _selectedDay.month + direction,
          1,
        ),
      };
    });
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _selectedDay = picked);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.selected,
    required this.hasEvents,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool hasEvents;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isToday =
        day.year == today.year &&
        day.month == today.month &&
        day.day == today.day;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: selected
              ? CosmicColors.accent.withValues(alpha: 0.28)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? CosmicColors.accent
                : isToday
                ? CosmicColors.accent2.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              formatWeekdayShortRu(day),
              style: TextStyle(
                fontSize: 10,
                color: selected ? CosmicColors.text : CosmicColors.muted,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? CosmicColors.text : CosmicColors.text2,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasEvents ? CosmicColors.accent2 : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.onTap,
    required this.onAction,
  });

  final Event event;
  final VoidCallback onTap;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final color = switch (event.status) {
      EventStatus.scheduled => CosmicColors.accent,
      EventStatus.completed => CosmicColors.success,
      EventStatus.cancelled => CosmicColors.danger,
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: CosmicColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: CosmicColors.line),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                margin: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            event.timeStart,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${event.durationMinutes} мин',
                            style: const TextStyle(
                              fontSize: 11,
                              color: CosmicColors.muted,
                            ),
                          ),
                          const Spacer(),
                          PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.more_horiz, size: 20),
                            onSelected: onAction,
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Редактировать'),
                              ),
                              if (event.status == EventStatus.scheduled)
                                const PopupMenuItem(
                                  value: 'complete',
                                  child: Text('Завершить'),
                                ),
                              if (event.status == EventStatus.cancelled)
                                const PopupMenuItem(
                                  value: 'reopen',
                                  child: Text('Вернуть в план'),
                                ),
                              if (event.status != EventStatus.cancelled)
                                const PopupMenuItem(
                                  value: 'cancel',
                                  child: Text('Отменить'),
                                ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Удалить'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        event.institutionName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        event.institutionAddress,
                        style: const TextStyle(
                          fontSize: 12,
                          color: CosmicColors.muted,
                        ),
                      ),
                      if (event.contactPerson.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          '${event.contactPerson} · ${event.contactPhone}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: CosmicColors.text2,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            childrenCountLabel(event.childrenCount),
                            style: const TextStyle(
                              fontSize: 11,
                              color: CosmicColors.text2,
                            ),
                          ),
                          Text(
                            '${formatRubles(event.pricePerChildKopecks)} · '
                            '${formatPercentBp(event.institutionPercentBp)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: CosmicColors.text2,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              formatRubles(event.grossKopecks),
                              style: TextStyle(fontSize: 11, color: color),
                            ),
                          ),
                        ],
                      ),
                      if (event.programName.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          event.programName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: CosmicColors.accent2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
