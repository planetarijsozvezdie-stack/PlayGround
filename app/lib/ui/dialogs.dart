import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/company_time.dart';
import '../core/money.dart';
import '../core/ru_format.dart';
import '../core/tax.dart';
import '../data/models.dart';
import '../state/providers.dart';
import '../state/reminders.dart';
import '../theme.dart';

const _uuid = Uuid();

Future<void> showAddEventDialog(
  BuildContext context,
  WidgetRef ref, {
  Event? event,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _EventDialog(event: event),
  );
}

Future<void> showAddInstitutionDialog(
  BuildContext context,
  WidgetRef ref, {
  Institution? institution,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _InstitutionDialog(institution: institution),
  );
}

Future<void> showAddRevenueDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _RevenueDialog(),
  );
}

Future<void> showSettingsDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _SettingsDialog(),
  );
}

Future<void> showInstitutionHistory(
  BuildContext context,
  WidgetRef ref,
  Institution institution,
) async {
  final repository = ref.read(repositoryProvider);
  final history = await repository.institutionHistory(institution.id);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(institution.name),
      content: SizedBox(
        width: 460,
        child: history.isEmpty
            ? const Text(
                'История пуста. Изменения появятся после редактирования карточки.',
                style: TextStyle(color: CosmicColors.muted),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: history.length,
                separatorBuilder: (_, _) => const Divider(height: 18),
                itemBuilder: (context, index) {
                  final entry = history[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_fieldLabel(entry.field)}: '
                        '${entry.oldValue.isEmpty ? '—' : entry.oldValue} → '
                        '${entry.newValue.isEmpty ? '—' : entry.newValue}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _formatDateTime(entry.changedAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: CosmicColors.muted,
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Закрыть'),
        ),
      ],
    ),
  );
}

String _fieldLabel(String field) => switch (field) {
  'name' => 'Название',
  'number' => 'Номер',
  'city' => 'Город',
  'district' => 'Район',
  'address' => 'Адрес',
  'contact_person' => 'Контактное лицо',
  'phone_primary' => 'Телефон',
  'phone_secondary' => 'Доп. телефон',
  'email' => 'Email',
  'status' => 'Статус',
  'type' => 'Тип',
  'tags' => 'Теги',
  '*' => 'Запись',
  _ => field,
};

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  return '${formatDateRu(local)} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

class _EventDialog extends ConsumerStatefulWidget {
  const _EventDialog({this.event});

  final Event? event;

  @override
  ConsumerState<_EventDialog> createState() => _EventDialogState();
}

class _EventDialogState extends ConsumerState<_EventDialog> {
  final _formKey = GlobalKey<FormState>();
  final _children = TextEditingController();
  final _price = TextEditingController();
  final _percent = TextEditingController();
  final _notes = TextEditingController();
  Institution? _institution;
  String? _programName;
  late DateTime _date;
  late TimeOfDay _time;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    final company = ref.read(sessionProvider).company;
    _date = event?.date ?? todayInCompany(company?.timezone ?? 'Europe/Moscow');
    if (event != null) {
      final parts = event.timeStart.split(':');
      _time = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      _programName = event.programName;
    } else {
      _time = const TimeOfDay(hour: 9, minute: 0);
    }
    _children.text = (event?.childrenCount ?? 25).toString();
    _price.text = ((event?.pricePerChildKopecks ?? 25000) / 100)
        .toStringAsFixed(0);
    _percent.text = ((event?.institutionPercentBp ?? 2500) / 100)
        .toStringAsFixed(0);
    _notes.text = event?.notes ?? '';
  }

  @override
  void dispose() {
    _children.dispose();
    _price.dispose();
    _percent.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final institutions =
        ref.watch(institutionsProvider).valueOrNull ?? const <Institution>[];
    final programs =
        ref.watch(programsProvider).valueOrNull ?? const <ProgramRecord>[];
    if (_institution == null && widget.event?.institutionId != null) {
      for (final item in institutions) {
        if (item.id == widget.event!.institutionId) {
          _institution = item;
        }
      }
    }
    final allPrograms = <String>{
      ...programs.map((p) => p.name),
      ?_programName,
    }.toList();

    return AlertDialog(
      title: Text(widget.event == null ? 'Новое мероприятие' : 'Мероприятие'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Institution>(
                  initialValue: _institution,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Учреждение'),
                  items: institutions
                      .map(
                        (i) => DropdownMenuItem(
                          value: i,
                          child: Text(
                            '${i.name} · ${i.city}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _institution = value;
                      _programName = null;
                    });
                  },
                  validator: (value) =>
                      value == null ? 'Выберите учреждение' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: allPrograms.contains(_programName)
                      ? _programName
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Программа'),
                  items: allPrograms
                      .map(
                        (name) => DropdownMenuItem(
                          value: name,
                          child: Text(name, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _programName = value),
                  validator: (value) =>
                      value == null ? 'Выберите программу' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                        ),
                        label: Text(formatDateRu(_date)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickTime,
                        icon: const Icon(Icons.schedule, size: 18),
                        label: Text(_timeLabel(_time)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _numberField(_children, 'Детей')),
                    const SizedBox(width: 10),
                    Expanded(child: _numberField(_price, 'Цена, ₽')),
                    const SizedBox(width: 10),
                    Expanded(child: _numberField(_percent, 'Доля, %')),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Примечания',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Длительность по умолчанию — 40 минут. '
                    'Статус меняется из карточки.',
                    style: TextStyle(fontSize: 11, color: CosmicColors.muted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: _save, child: const Text('Сохранить')),
      ],
    );
  }

  Widget _numberField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        final parsed = double.tryParse((value ?? '').replaceAll(',', '.'));
        if (parsed == null || parsed < 0) return 'Число';
        return null;
      },
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _time = picked);
  }

  String _timeLabel(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final institution = _institution;
    final company = ref.read(sessionProvider).company;
    if (institution == null || company == null) return;
    final children = int.tryParse(_children.text) ?? 0;
    final price = rubToKopecks(
      double.tryParse(_price.text.replaceAll(',', '.')) ?? 0,
    );
    final percent =
        (100 * (double.tryParse(_percent.text.replaceAll(',', '.')) ?? 0))
            .round();
    final time =
        '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';
    final event = widget.event == null
        ? Event.draft(
            id: _uuid.v4(),
            companyId: company.id,
            institution: institution,
            date: _date,
            timeStart: time,
            timezone: company.timezone,
            programName: _programName ?? '',
            childrenCount: children,
            pricePerChildKopecks: price,
            institutionPercentBp: percent,
            notes: _notes.text.trim(),
          )
        : widget.event!.copyWith(
            institution: institution,
            date: _date,
            timeStart: time,
            programName: _programName,
            childrenCount: children,
            pricePerChildKopecks: price,
            institutionPercentBp: percent,
            notes: _notes.text.trim(),
          );
    await ref.read(repositoryProvider).saveEvent(event);
    invalidateBusinessData(ref);
    unawaited(refreshReminders(ref));
    if (mounted) Navigator.pop(context);
  }
}

class _InstitutionDialog extends ConsumerStatefulWidget {
  const _InstitutionDialog({this.institution});

  final Institution? institution;

  @override
  ConsumerState<_InstitutionDialog> createState() => _InstitutionDialogState();
}

class _InstitutionDialogState extends ConsumerState<_InstitutionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _number;
  late final TextEditingController _name;
  late final TextEditingController _city;
  late final TextEditingController _district;
  late final TextEditingController _address;
  late final TextEditingController _contact;
  late final TextEditingController _position;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _tags;
  late final TextEditingController _notes;
  late InstitutionType _type;
  late InstitutionStatus _status;
  late CounterpartyType _counterparty;

  @override
  void initState() {
    super.initState();
    final i = widget.institution;
    _type = i?.type ?? InstitutionType.kindergarten;
    _status = i?.status ?? InstitutionStatus.active;
    _counterparty = i?.counterparty ?? CounterpartyType.legal;
    _number = TextEditingController(text: i?.number ?? '');
    _name = TextEditingController(text: i?.name ?? '');
    _city = TextEditingController(
      text: i?.city ?? ref.read(sessionProvider).company?.city ?? '',
    );
    _district = TextEditingController(text: i?.district ?? '');
    _address = TextEditingController(text: i?.address ?? '');
    _contact = TextEditingController(text: i?.contactPerson ?? '');
    _position = TextEditingController(text: i?.position ?? '');
    _phone = TextEditingController(text: i?.phonePrimary ?? '');
    _email = TextEditingController(text: i?.email ?? '');
    _tags = TextEditingController(text: i?.tags.join(', ') ?? '');
    _notes = TextEditingController(text: i?.notes ?? '');
  }

  @override
  void dispose() {
    for (final controller in [
      _number,
      _name,
      _city,
      _district,
      _address,
      _contact,
      _position,
      _phone,
      _email,
      _tags,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.institution == null ? 'Новое учреждение' : 'Учреждение',
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<InstitutionType>(
                        initialValue: _type,
                        decoration: const InputDecoration(labelText: 'Тип'),
                        items: InstitutionType.values
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(type.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _type = value ?? _type),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: _textField(_number, 'Номер')),
                  ],
                ),
                const SizedBox(height: 12),
                _textField(_name, 'Название', required: true),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _textField(_city, 'Город', required: true)),
                    const SizedBox(width: 10),
                    Expanded(child: _textField(_district, 'Район')),
                  ],
                ),
                const SizedBox(height: 12),
                _textField(_address, 'Адрес'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _textField(_contact, 'Контактное лицо')),
                    const SizedBox(width: 10),
                    Expanded(child: _textField(_position, 'Должность')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _textField(_phone, 'Телефон')),
                    const SizedBox(width: 10),
                    Expanded(child: _textField(_email, 'Email')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<CounterpartyType>(
                        initialValue: _counterparty,
                        decoration: const InputDecoration(
                          labelText: 'Тип контрагента для налога',
                        ),
                        items: CounterpartyType.values
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(
                                  '${type.label} · ${TaxCalculator.rateBpFor(type) / 100}%',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(
                          () => _counterparty = value ?? _counterparty,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<InstitutionStatus>(
                        initialValue: _status,
                        decoration: const InputDecoration(labelText: 'Статус'),
                        items: InstitutionStatus.values
                            .map(
                              (status) => DropdownMenuItem(
                                value: status,
                                child: Text(status.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _status = value ?? _status),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _textField(_tags, 'Теги через запятую'),
                const SizedBox(height: 12),
                _textField(_notes, 'Заметки'),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: _save, child: const Text('Сохранить')),
      ],
    );
  }

  List<String> _parseTags(String raw) {
    final tags = <String>[];
    for (final part in raw.split(RegExp(r'[,;]'))) {
      final tag = part.trim();
      if (tag.isNotEmpty && !tags.contains(tag)) tags.add(tag);
    }
    return tags;
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    bool required = false,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      validator: required
          ? (value) => (value == null || value.trim().isEmpty)
                ? 'Заполните поле'
                : null
          : null,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final company = ref.read(sessionProvider).company;
    if (company == null) return;
    final previous = widget.institution;
    final institution = Institution(
      id: previous?.id ?? _uuid.v4(),
      companyId: company.id,
      type: _type,
      number: _number.text.trim(),
      name: _name.text.trim(),
      city: _city.text.trim(),
      district: _district.text.trim(),
      address: _address.text.trim(),
      contactPerson: _contact.text.trim(),
      position: _position.text.trim(),
      phonePrimary: _phone.text.trim(),
      phoneSecondary: previous?.phoneSecondary ?? '',
      email: _email.text.trim(),
      website: previous?.website ?? '',
      groupsCount: previous?.groupsCount,
      hallCapacity: previous?.hallCapacity,
      notes: previous?.notes ?? '',
      lastVisitDate: previous?.lastVisitDate,
      totalVisits: previous?.totalVisits ?? 0,
      status: _status,
      tags: _parseTags(_tags.text),
      counterparty: _counterparty,
      externalId: previous?.externalId ?? _uuid.v4(),
    );
    await ref.read(repositoryProvider).saveInstitution(institution);
    invalidateBusinessData(ref);
    if (mounted) Navigator.pop(context);
  }
}

class _RevenueDialog extends ConsumerStatefulWidget {
  const _RevenueDialog();

  @override
  ConsumerState<_RevenueDialog> createState() => _RevenueDialogState();
}

class _RevenueDialogState extends ConsumerState<_RevenueDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _comment = TextEditingController();
  DateTime _date = DateTime.now();
  CounterpartyType _counterparty = CounterpartyType.legal;
  String _category = 'session';

  @override
  void dispose() {
    _amount.dispose();
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ручная запись выручки'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Сумма, ₽'),
                validator: (value) {
                  final parsed = double.tryParse(
                    (value ?? '').replaceAll(',', '.'),
                  );
                  if (parsed == null || parsed <= 0) return 'Введите сумму';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text(formatDateRu(_date)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: const InputDecoration(labelText: 'Категория'),
                      items: const [
                        DropdownMenuItem(
                          value: 'session',
                          child: Text('Сеансы'),
                        ),
                        DropdownMenuItem(value: 'other', child: Text('Прочее')),
                      ],
                      onChanged: (value) =>
                          setState(() => _category = value ?? 'session'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CounterpartyType>(
                initialValue: _counterparty,
                decoration: const InputDecoration(labelText: 'Контрагент'),
                items: CounterpartyType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(
                          '${type.label} · ${TaxCalculator.rateBpFor(type) / 100}%',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _counterparty = value ?? _counterparty),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _comment,
                decoration: const InputDecoration(labelText: 'Комментарий'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: _save, child: const Text('Добавить')),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final company = ref.read(sessionProvider).company;
    if (company == null) return;
    final amount = rubToKopecks(
      double.tryParse(_amount.text.replaceAll(',', '.')) ?? 0,
    );
    final revenue = Revenue(
      id: _uuid.v4(),
      companyId: company.id,
      eventId: null,
      date: _date,
      amountKopecks: amount,
      grossKopecks: null,
      category: _category,
      counterparty: _counterparty,
      taxRateBp: 0,
      taxBaseKopecks: amount,
      taxDeductionKopecks: 0,
      taxAmountKopecks: 0,
      isAuto: false,
      isReversed: false,
      reversalOfId: null,
      comment: _comment.text.trim(),
    );
    await ref.read(repositoryProvider).addRevenue(revenue);
    ref.invalidate(revenuesProvider);
    ref.invalidate(statsProvider);
    ref.invalidate(outboxProvider);
    if (mounted) Navigator.pop(context);
  }
}

class _SettingsDialog extends ConsumerStatefulWidget {
  const _SettingsDialog();

  @override
  ConsumerState<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<_SettingsDialog> {
  String? _revenueMode;
  String? _taxBase;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repository = ref.read(repositoryProvider);
    final mode = await repository.setting('revenue_mode', 'auto');
    final base = await repository.setting('tax_base', 'received');
    if (!mounted) return;
    setState(() {
      _revenueMode = mode;
      _taxBase = base;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Настройки расчётов'),
      content: SizedBox(
        width: 420,
        child: _revenueMode == null
            ? const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _revenueMode,
                    decoration: const InputDecoration(
                      labelText: 'Начисление выручки',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'auto',
                        child: Text('Автоматически'),
                      ),
                      DropdownMenuItem(
                        value: 'confirm',
                        child: Text('После подтверждения'),
                      ),
                    ],
                    onChanged: (value) => setState(() => _revenueMode = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _taxBase,
                    decoration: const InputDecoration(
                      labelText: 'Налоговая база',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'received',
                        child: Text('Полученная сумма (после доли сада)'),
                      ),
                      DropdownMenuItem(
                        value: 'gross',
                        child: Text('Полная стоимость сеанса'),
                      ),
                    ],
                    onChanged: (value) => setState(() => _taxBase = value),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'НПД: 6% с юрлиц, 4% с физлиц, '
                    'вычет 10 000 ₽ применяется автоматически. '
                    'Сумма налога — оценка, чеки формируются в «Мой налог».',
                    style: TextStyle(
                      fontSize: 11,
                      color: CosmicColors.muted,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: _save, child: const Text('Сохранить')),
      ],
    );
  }

  Future<void> _save() async {
    final repository = ref.read(repositoryProvider);
    await repository.setSetting('revenue_mode', _revenueMode ?? 'auto');
    await repository.setSetting('tax_base', _taxBase ?? 'received');
    if (!mounted) return;
    Navigator.pop(context);
  }
}
