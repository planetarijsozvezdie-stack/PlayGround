import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/contact_links.dart';
import '../core/export_data.dart';
import '../core/ru_format.dart';
import '../data/models.dart';
import '../state/providers.dart';
import '../theme.dart';
import 'dialogs.dart';
import 'export_action.dart';
import 'import_institutions.dart';

class InstitutionsScreen extends ConsumerStatefulWidget {
  const InstitutionsScreen({super.key, required this.company});

  final Company company;

  @override
  ConsumerState<InstitutionsScreen> createState() => _InstitutionsScreenState();
}

const String _allFilterValue = '__all__';

enum _InstitutionSort {
  name('По названию'),
  city('По городу'),
  lastVisit('По последнему визиту'),
  visits('По числу сеансов');

  const _InstitutionSort(this.label);

  final String label;
}

class _InstitutionsScreenState extends ConsumerState<InstitutionsScreen> {
  final _search = TextEditingController();
  InstitutionType? _type;
  InstitutionStatus? _status;
  _InstitutionSort _sort = _InstitutionSort.name;
  String? _city;
  String? _district;
  String? _tag;
  bool _selecting = false;
  bool _table = false;
  final Set<String> _selected = {};
  final Set<String> _hidden = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all =
        (ref.watch(institutionsProvider).valueOrNull ?? const <Institution>[])
            .where((i) => !_hidden.contains(i.id))
            .toList();
    final query = _search.text.trim().toLowerCase();
    final cities =
        all.map((i) => i.city).where((city) => city.isNotEmpty).toSet().toList()
          ..sort();
    final districts =
        all
            .where((i) => _city == null || i.city == _city)
            .map((i) => i.district)
            .where((district) => district.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final tags = all.expand((i) => i.tags).toSet().toList()..sort();
    final filtered = all
        .where((i) => _type == null || i.type == _type)
        .where((i) => _status == null || i.status == _status)
        .where((i) => _city == null || i.city == _city)
        .where((i) => _district == null || i.district == _district)
        .where((i) => _tag == null || i.tags.contains(_tag))
        .where((i) => query.isEmpty || i.searchBlob.contains(query))
        .toList();
    filtered.sort(switch (_sort) {
      _InstitutionSort.name => (a, b) => a.name.compareTo(b.name),
      _InstitutionSort.city => (a, b) {
        final city = a.city.compareTo(b.city);
        return city == 0 ? a.name.compareTo(b.name) : city;
      },
      _InstitutionSort.lastVisit => (a, b) {
        final left = a.lastVisitDate;
        final right = b.lastVisitDate;
        if (left == null && right == null) return a.name.compareTo(b.name);
        if (left == null) return 1;
        if (right == null) return -1;
        return right.compareTo(left);
      },
      _InstitutionSort.visits => (a, b) {
        final visits = b.totalVisits.compareTo(a.totalVisits);
        return visits == 0 ? a.name.compareTo(b.name) : visits;
      },
    });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Column(
            children: [
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Название, адрес, контакт, телефон',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _search.clear();
                            setState(() {});
                          },
                        ),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: const Text('Все'),
                        selected: _type == null,
                        onSelected: (_) => setState(() => _type = null),
                      ),
                    ),
                    for (final type in InstitutionType.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(type.label),
                          selected: _type == type,
                          onSelected: (_) => setState(() => _type = type),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterMenu(
                      label: 'Город',
                      options: cities,
                      value: _city,
                      onChanged: (value) => setState(() {
                        _city = value;
                        if (value == null ||
                            !all.any(
                              (i) => i.city == value && i.district == _district,
                            )) {
                          _district = null;
                        }
                      }),
                    ),
                    const SizedBox(width: 8),
                    _FilterMenu(
                      label: 'Район',
                      options: districts,
                      value: _district,
                      onChanged: (value) => setState(() => _district = value),
                    ),
                    const SizedBox(width: 8),
                    _FilterMenu(
                      label: 'Тег',
                      options: tags,
                      value: _tag,
                      onChanged: (value) => setState(() => _tag = value),
                    ),
                  ],
                ),
              ),
              if (_status != null) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    label: Text('Статус: ${_status!.label}'),
                    onDeleted: () => setState(() => _status = null),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Найдено: ${filtered.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: CosmicColors.muted,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: _table ? 'Карточки' : 'Табличный вид',
                    onPressed: () => setState(() => _table = !_table),
                    icon: Icon(
                      _table
                          ? Icons.grid_view_outlined
                          : Icons.table_rows_outlined,
                      size: 18,
                    ),
                  ),
                  IconButton(
                    tooltip: _selecting
                        ? 'Завершить выбор'
                        : 'Выбрать несколько',
                    onPressed: () => setState(() {
                      _selecting = !_selecting;
                      if (!_selecting) _selected.clear();
                    }),
                    icon: Icon(
                      _selecting ? Icons.close : Icons.check_box_outlined,
                      size: 18,
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Фильтр по статусу',
                    initialValue: _status?.name ?? _allFilterValue,
                    onSelected: (value) => setState(() {
                      _status = value == _allFilterValue
                          ? null
                          : InstitutionStatus.values.firstWhere(
                              (status) => status.name == value,
                            );
                    }),
                    icon: Icon(
                      Icons.verified_outlined,
                      size: 18,
                      color: _status == null
                          ? CosmicColors.muted
                          : CosmicColors.accent2,
                    ),
                    itemBuilder: (context) => [
                      const PopupMenuItem<String>(
                        value: _allFilterValue,
                        child: Text('Все статусы'),
                      ),
                      for (final status in InstitutionStatus.values)
                        PopupMenuItem<String>(
                          value: status.name,
                          child: Text(status.label),
                        ),
                    ],
                  ),
                  PopupMenuButton<_InstitutionSort>(
                    tooltip: 'Сортировка',
                    initialValue: _sort,
                    onSelected: (value) => setState(() => _sort = value),
                    icon: const Icon(Icons.sort, size: 18),
                    itemBuilder: (context) => [
                      for (final sort in _InstitutionSort.values)
                        PopupMenuItem(value: sort, child: Text(sort.label)),
                    ],
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Экспорт и импорт',
                    icon: const Icon(Icons.swap_vert, size: 18),
                    onSelected: (value) {
                      if (value == 'import') {
                        showInstitutionImport(context, ref, widget.company);
                        return;
                      }
                      exportTable(context, institutionsTable(filtered), value);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'xlsx', child: Text('Экспорт XLSX')),
                      PopupMenuItem(value: 'csv', child: Text('Экспорт CSV')),
                      PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'import',
                        child: Text('Импорт XLSX/CSV'),
                      ),
                    ],
                  ),
                ],
              ),
              if (_selecting) _buildSelectionBar(),
              const SizedBox(height: 4),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text(
                    'Ничего не найдено',
                    style: TextStyle(color: CosmicColors.muted),
                  ),
                )
              : _table
              ? Column(
                  children: [
                    _InstitutionTableHeader(selecting: _selecting),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final institution = filtered[index];
                          return _InstitutionTableRow(
                            institution: institution,
                            selecting: _selecting,
                            selected: _selected.contains(institution.id),
                            onSelected: (_) => _toggleSelected(institution.id),
                            onTap: () => _openInstitution(institution),
                          );
                        },
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final institution = filtered[index];
                    return _InstitutionCard(
                      institution: institution,
                      selecting: _selecting,
                      selected: _selected.contains(institution.id),
                      onSelected: (_) => _toggleSelected(institution.id),
                      onTap: () => _openInstitution(institution),
                      onAction: (action) => _handleAction(institution, action),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _toggleSelected(String id) {
    setState(() {
      if (!_selected.add(id)) _selected.remove(id);
    });
  }

  void _openInstitution(Institution institution) {
    if (_selecting) {
      _toggleSelected(institution.id);
      return;
    }
    showAddInstitutionDialog(context, ref, institution: institution);
  }

  Widget _buildSelectionBar() {
    final count = _selected.length;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: CosmicColors.background2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CosmicColors.line),
        ),
        child: Row(
          children: [
            Text(
              'Выбрано: $count',
              style: const TextStyle(fontSize: 12, color: CosmicColors.text2),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Отметить проверенными',
              onPressed: count == 0
                  ? null
                  : () => _bulkStatus(InstitutionStatus.verified),
              icon: const Icon(Icons.verified_outlined, size: 20),
            ),
            PopupMenuButton<InstitutionStatus>(
              tooltip: 'Изменить статус',
              enabled: count > 0,
              onSelected: _bulkStatus,
              icon: const Icon(Icons.flag_outlined, size: 20),
              itemBuilder: (context) => [
                for (final status in InstitutionStatus.values)
                  PopupMenuItem(value: status, child: Text(status.label)),
              ],
            ),
            IconButton(
              tooltip: 'Удалить выбранные',
              onPressed: count == 0 ? null : _bulkDelete,
              icon: const Icon(Icons.delete_outline, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _bulkStatus(InstitutionStatus status) async {
    final all =
        ref.read(institutionsProvider).valueOrNull ?? const <Institution>[];
    final targets = all
        .where((institution) => _selected.contains(institution.id))
        .toList();
    if (targets.isEmpty) return;
    for (final institution in targets) {
      await ref
          .read(repositoryProvider)
          .saveInstitution(institution.copyWith(status: status));
    }
    invalidateBusinessData(ref);
    if (!mounted) return;
    final count = targets.length;
    setState(() {
      _selected.clear();
      _selecting = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Статус «${status.label}» установлен: $count '
          '${pluralRu(count, 'учреждение', 'учреждения', 'учреждений')}',
        ),
      ),
    );
  }

  Future<void> _bulkDelete() async {
    final count = _selected.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить выбранные учреждения?'),
        content: Text(
          '$count '
          '${pluralRu(count, 'учреждение', 'учреждения', 'учреждений')} '
          'пропадут из базы. Мероприятия и документы сохранятся.',
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
    if (confirmed != true) return;
    for (final id in [..._selected]) {
      await ref.read(repositoryProvider).deleteInstitution(id);
    }
    invalidateBusinessData(ref);
    if (!mounted) return;
    setState(() {
      _selected.clear();
      _selecting = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Удалено: $count '
          '${pluralRu(count, 'учреждение', 'учреждения', 'учреждений')}',
        ),
      ),
    );
  }

  Future<void> _composeEmail(Institution institution) async {
    final uri = institutionEmailUri(
      company: widget.company,
      institution: institution,
    );
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) throw StateError('почтовый клиент не найден');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть почту: $error')),
      );
    }
  }

  Future<void> _forceDelete(Institution institution) async {
    _hidden.add(institution.id);
    setState(() {});
    await ref.read(repositoryProvider).deleteInstitution(institution.id);
    invalidateBusinessData(ref);
  }

  Future<void> _handleAction(Institution institution, String action) async {
    switch (action) {
      case 'edit':
        await showAddInstitutionDialog(context, ref, institution: institution);
      case 'verify':
        final next = institution.status == InstitutionStatus.verified
            ? InstitutionStatus.active
            : InstitutionStatus.verified;
        await ref
            .read(repositoryProvider)
            .saveInstitution(institution.copyWith(status: next));
        invalidateBusinessData(ref);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next == InstitutionStatus.verified
                  ? 'Учреждение отмечено проверенным'
                  : 'Отметка «проверено» снята',
            ),
          ),
        );
      case 'email':
        await _composeEmail(institution);
      case 'history':
        await showInstitutionHistory(context, ref, institution);
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Удалить учреждение?'),
            content: Text(
              '${institution.name} пропадёт из базы. '
              'Мероприятия и документы сохранятся.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: CosmicColors.danger,
                ),
                child: const Text('Удалить'),
              ),
            ],
          ),
        );
        if (confirmed ?? false) {
          await _forceDelete(institution);
        }
      case 'forceDelete':
        await _forceDelete(institution);
    }
  }
}

class _InstitutionCard extends StatelessWidget {
  const _InstitutionCard({
    required this.institution,
    required this.onTap,
    required this.onAction,
    required this.selecting,
    required this.selected,
    required this.onSelected,
  });

  final Institution institution;
  final VoidCallback onTap;
  final ValueChanged<String> onAction;
  final bool selecting;
  final bool selected;
  final ValueChanged<bool?> onSelected;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (institution.status) {
      InstitutionStatus.verified => CosmicColors.success,
      InstitutionStatus.active => CosmicColors.accent2,
      InstitutionStatus.inactive => CosmicColors.muted,
    };
    return Dismissible(
      key: ValueKey(institution.id),
      direction: selecting
          ? DismissDirection.none
          : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: CosmicColors.danger.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: CosmicColors.danger),
      ),
      confirmDismiss: (_) async {
        final result = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Удалить учреждение?'),
            content: Text('${institution.name} пропадёт из базы.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: CosmicColors.danger,
                ),
                child: const Text('Удалить'),
              ),
            ],
          ),
        );
        return result ?? false;
      },
      onDismissed: (_) => onAction('forceDelete'),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: CosmicColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: CosmicColors.line),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selecting)
                  Checkbox(
                    value: selected,
                    onChanged: onSelected,
                    visualDensity: VisualDensity.compact,
                  )
                else
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: CosmicColors.background2,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      switch (institution.type) {
                        InstitutionType.kindergarten =>
                          Icons.child_care_outlined,
                        InstitutionType.school => Icons.school_outlined,
                        InstitutionType.other => Icons.auto_awesome_outlined,
                      },
                      size: 21,
                      color: CosmicColors.accent2,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              institution.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (!selecting)
                            PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.more_vert, size: 18),
                              onSelected: onAction,
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Редактировать'),
                                ),
                                PopupMenuItem(
                                  value: 'verify',
                                  child: Text(
                                    institution.status ==
                                            InstitutionStatus.verified
                                        ? 'Снять отметку «проверено»'
                                        : 'Отметить проверенным',
                                  ),
                                ),
                                if (institution.email.isNotEmpty)
                                  const PopupMenuItem(
                                    value: 'email',
                                    child: Text('Написать письмо'),
                                  ),
                                const PopupMenuItem(
                                  value: 'history',
                                  child: Text('История изменений'),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Удалить'),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${institution.city}'
                        '${institution.district.isEmpty ? '' : ', ${institution.district}'}'
                        '${institution.address.isEmpty ? '' : ', ${institution.address}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: CosmicColors.muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (institution.contactPerson.isNotEmpty) ...[
                            const Icon(
                              Icons.person_outline,
                              size: 13,
                              color: CosmicColors.muted,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                institution.contactPerson,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: CosmicColors.text2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          if (institution.phonePrimary.isNotEmpty) ...[
                            const Icon(
                              Icons.phone_outlined,
                              size: 13,
                              color: CosmicColors.muted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              institution.phonePrimary,
                              style: const TextStyle(
                                fontSize: 11,
                                color: CosmicColors.text2,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _Tag(
                            text: institution.type.label,
                            color: CosmicColors.accent,
                          ),
                          _Tag(
                            text: institution.status.label,
                            color: statusColor,
                          ),
                          for (final tag in institution.tags)
                            _Tag(text: tag, color: CosmicColors.warning),
                          Text(
                            sessionsCountLabel(institution.totalVisits),
                            style: const TextStyle(
                              fontSize: 10,
                              color: CosmicColors.muted,
                            ),
                          ),
                          if (institution.lastVisitDate != null)
                            Text(
                              'был ${formatDateShortRu(institution.lastVisitDate!)}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: CosmicColors.muted,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, color: color)),
    );
  }
}

class _InstitutionTableHeader extends StatelessWidget {
  const _InstitutionTableHeader({required this.selecting});

  final bool selecting;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 10,
      color: CosmicColors.muted,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
      child: Row(
        children: [
          if (selecting) const SizedBox(width: 40),
          const SizedBox(width: 16),
          const Expanded(child: Text('Учреждение', style: style)),
          const SizedBox(
            width: 44,
            child: Text('Сеансы', textAlign: TextAlign.right, style: style),
          ),
          const SizedBox(
            width: 62,
            child: Text('Был', textAlign: TextAlign.right, style: style),
          ),
        ],
      ),
    );
  }
}

class _InstitutionTableRow extends StatelessWidget {
  const _InstitutionTableRow({
    required this.institution,
    required this.selecting,
    required this.selected,
    required this.onSelected,
    required this.onTap,
  });

  final Institution institution;
  final bool selecting;
  final bool selected;
  final ValueChanged<bool?> onSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(institution.status);
    final location = [
      institution.city,
      if (institution.district.isNotEmpty) institution.district,
    ].join(', ');
    final lastVisit = institution.lastVisitDate;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: CosmicColors.line)),
          ),
          child: Row(
            children: [
              if (selecting)
                SizedBox(
                  width: 40,
                  child: Checkbox(
                    value: selected,
                    onChanged: onSelected,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              Tooltip(
                message: institution.status.label,
                child: Icon(
                  switch (institution.status) {
                    InstitutionStatus.verified => Icons.verified_outlined,
                    InstitutionStatus.active => Icons.flag_outlined,
                    InstitutionStatus.inactive => Icons.remove_circle_outline,
                  },
                  size: 14,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        institution.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (location.isNotEmpty)
                        Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: CosmicColors.muted,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 44,
                child: Text(
                  '${institution.totalVisits}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              SizedBox(
                width: 62,
                child: Text(
                  lastVisit == null ? '—' : formatDateShortRu(lastVisit),
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
      ),
    );
  }
}

class _FilterMenu extends StatelessWidget {
  const _FilterMenu({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<String> options;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final active = value != null;
    return PopupMenuButton<String>(
      tooltip: '$label: все',
      enabled: options.isNotEmpty || active,
      initialValue: value ?? _allFilterValue,
      onSelected: (selected) =>
          onChanged(selected == _allFilterValue ? null : selected),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: _allFilterValue,
          child: Text('Все: $label'),
        ),
        for (final option in options)
          PopupMenuItem<String>(value: option, child: Text(option)),
      ],
      child: Chip(
        label: Text(active ? value! : label),
        avatar: Icon(
          active ? Icons.filter_alt : Icons.filter_alt_outlined,
          size: 15,
          color: active ? CosmicColors.accent2 : CosmicColors.muted,
        ),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

Color _statusColor(InstitutionStatus status) {
  return switch (status) {
    InstitutionStatus.verified => CosmicColors.success,
    InstitutionStatus.active => CosmicColors.accent2,
    InstitutionStatus.inactive => CosmicColors.muted,
  };
}
