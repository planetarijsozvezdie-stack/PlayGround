import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

import '../core/contract_pdf.dart';
import '../core/event_rules.dart';
import '../core/ru_format.dart';
import '../data/models.dart';
import '../state/providers.dart';
import '../theme.dart';
import 'document_store.dart';
import 'pdf_preview.dart';

const _uuid = Uuid();

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key, required this.company});

  final Company company;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: TabBar(
              indicatorColor: CosmicColors.accent2,
              labelColor: CosmicColors.text,
              unselectedLabelColor: CosmicColors.muted,
              tabs: [
                Tab(text: 'Программы'),
                Tab(text: 'Шаблоны'),
                Tab(text: 'Архив'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                const _ProgramsTab(),
                _TemplatesTab(company: company),
                _ArchiveTab(company: company),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgramsTab extends ConsumerWidget {
  const _ProgramsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programs =
        ref.watch(programsProvider).valueOrNull ?? const <ProgramRecord>[];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHint(
          '${programsCountLabel(programs.length)} · PDF-файлы хранятся на устройстве',
        ),
        const SizedBox(height: 10),
        for (final program in programs)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: CosmicColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: CosmicColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.picture_as_pdf_outlined,
                        size: 20,
                        color: CosmicColors.danger,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          program.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      _Badge(
                        text: program.audience == InstitutionType.kindergarten
                            ? 'сад'
                            : 'школа',
                        color: CosmicColors.accent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    program.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: CosmicColors.muted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${program.ageGroup} · ${program.durationMinutes} мин',
                    style: const TextStyle(
                      fontSize: 11,
                      color: CosmicColors.text2,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _TemplatesTab extends ConsumerWidget {
  const _TemplatesTab({required this.company});

  final Company company;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates =
        ref.watch(templatesProvider).valueOrNull ?? const <TemplateRecord>[];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionHint(
          '4 шаблона: компания × тип учреждения. '
          'Переменные подставляются из мероприятия.',
        ),
        const SizedBox(height: 10),
        for (final template in templates)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: CosmicColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: CosmicColors.line),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.description_outlined,
                    size: 22,
                    color: CosmicColors.accent2,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          template.type.label,
                          style: const TextStyle(
                            fontSize: 11,
                            color: CosmicColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (context) => _TemplateEditorDialog(
                        company: company,
                        template: template,
                      ),
                    ),
                    child: const Text('Редактировать'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _TemplateEditorDialog extends ConsumerStatefulWidget {
  const _TemplateEditorDialog({required this.company, required this.template});

  final Company company;
  final TemplateRecord template;

  @override
  ConsumerState<_TemplateEditorDialog> createState() =>
      _TemplateEditorDialogState();
}

class _TemplateEditorDialogState extends ConsumerState<_TemplateEditorDialog> {
  late final TextEditingController _body;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _body = TextEditingController(text: widget.template.body)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Event? _previewEvent() {
    final events = ref.watch(eventsProvider).valueOrNull ?? const <Event>[];
    final institutions =
        ref.watch(institutionsProvider).valueOrNull ?? const <Institution>[];
    final types = {
      for (final institution in institutions) institution.id: institution.type,
    };
    final completed =
        events
            .where(
              (event) =>
                  event.status == EventStatus.completed &&
                  types[event.institutionId] == widget.template.type,
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return completed.firstOrNull;
  }

  String _previewText(Event? event) {
    if (event == null) return _body.text;
    return fillTemplate(
      _body.text,
      company: widget.company,
      event: event,
      documentNumber: 'ПРЕДПРОСМОТР',
      documentDate: event.date,
    );
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref
          .read(repositoryProvider)
          .saveTemplate(
            TemplateRecord(
              id: widget.template.id,
              companyId: widget.template.companyId,
              type: widget.template.type,
              name: widget.template.name,
              body: _body.text,
            ),
          );
      ref.invalidate(templatesProvider);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(content: Text('Шаблон сохранён')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось сохранить шаблон: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = _previewEvent();
    return AlertDialog(
      title: Text(widget.template.name),
      content: SizedBox(
        width: 560,
        height: 460,
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const TabBar(
                labelColor: CosmicColors.text,
                unselectedLabelColor: CosmicColors.muted,
                indicatorColor: CosmicColors.accent2,
                tabs: [
                  Tab(text: 'Редактор'),
                  Tab(text: 'Предпросмотр'),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  children: [
                    TextField(
                      controller: _body,
                      expands: true,
                      maxLines: null,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 1.45,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Текст шаблона с переменными {{...}}',
                        alignLabelWithHint: true,
                      ),
                    ),
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(8),
                      child: SelectableText(
                        _previewText(event),
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.5,
                          color: CosmicColors.text2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Сохранить'),
        ),
      ],
    );
  }
}

enum _DocumentKind {
  contract('contract', 'Д', 'Договор'),
  act('act', 'А', 'Акт'),
  invoice('invoice', 'С', 'Счёт');

  const _DocumentKind(this.dbType, this.code, this.title);

  final String dbType;
  final String code;
  final String title;

  String get actionTitle => switch (this) {
    _DocumentKind.contract => 'Сформировать договор',
    _DocumentKind.act => 'Сформировать акт',
    _DocumentKind.invoice => 'Сформировать счёт',
  };
}

enum _DocumentSort {
  newest('Сначала новые'),
  oldest('Сначала старые'),
  number('По номеру'),
  title('По названию');

  const _DocumentSort(this.label);

  final String label;
}

enum _DocumentAction { open, share, toggleSigned, delete }

class _ArchiveTab extends ConsumerStatefulWidget {
  const _ArchiveTab({required this.company});

  final Company company;

  @override
  ConsumerState<_ArchiveTab> createState() => _ArchiveTabState();
}

class _ArchiveTabState extends ConsumerState<_ArchiveTab> {
  final _search = TextEditingController();
  _DocumentSort _sort = _DocumentSort.newest;
  bool _signedOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<DocumentRecord> _visible(List<DocumentRecord> documents) {
    final query = _search.text.trim().toLowerCase();
    final filtered =
        (query.isEmpty
                ? [...documents]
                : documents.where((document) {
                    final created = document.createdAt.toLocal();
                    final date = formatDateRu(created);
                    final numericDate =
                        '${created.day.toString().padLeft(2, '0')}.'
                        '${created.month.toString().padLeft(2, '0')}.${created.year}';
                    return document.title.toLowerCase().contains(query) ||
                        document.number.toLowerCase().contains(query) ||
                        date.toLowerCase().contains(query) ||
                        numericDate.contains(query);
                  }).toList())
            .where((document) => !_signedOnly || document.signed)
            .toList();
    filtered.sort(switch (_sort) {
      _DocumentSort.newest => (a, b) => b.createdAt.compareTo(a.createdAt),
      _DocumentSort.oldest => (a, b) => a.createdAt.compareTo(b.createdAt),
      _DocumentSort.number => (a, b) => a.number.compareTo(b.number),
      _DocumentSort.title => (a, b) => a.title.compareTo(b.title),
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final documents =
        ref.watch(documentsProvider).valueOrNull ?? const <DocumentRecord>[];
    final visible = _visible(documents);
    final completed = (ref.watch(eventsProvider).valueOrNull ?? const <Event>[])
        .where((e) => e.status == EventStatus.completed)
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _SectionHint(
                '${documentsCountLabel(visible.length)}'
                '${_search.text.trim().isEmpty ? '' : ' из ${documents.length}'}'
                ' · ${kIsWeb ? 'PDF доступны до перезагрузки страницы' : 'локальное хранилище'}',
              ),
            ),
            FilledButton.icon(
              onPressed: completed.isEmpty
                  ? null
                  : () => _openGenerator(
                      context,
                      widget.company,
                      completed,
                      _DocumentKind.contract,
                    ),
              icon: const Icon(Icons.picture_as_pdf, size: 18),
              label: const Text('Договор'),
            ),
            PopupMenuButton<_DocumentKind>(
              tooltip: 'Акт или счёт',
              enabled: completed.isNotEmpty,
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (kind) =>
                  _openGenerator(context, widget.company, completed, kind),
              itemBuilder: (context) => const [
                PopupMenuItem(value: _DocumentKind.act, child: Text('Акт')),
                PopupMenuItem(
                  value: _DocumentKind.invoice,
                  child: Text('Счёт'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Поиск по названию, номеру или дате',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Очистить',
                          onPressed: () {
                            _search.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close, size: 18),
                        ),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Только подписанные',
              onPressed: () => setState(() => _signedOnly = !_signedOnly),
              icon: Icon(
                Icons.verified_outlined,
                size: 20,
                color: _signedOnly ? CosmicColors.accent2 : CosmicColors.muted,
              ),
            ),
            PopupMenuButton<_DocumentSort>(
              tooltip: 'Сортировка',
              initialValue: _sort,
              onSelected: (value) => setState(() => _sort = value),
              icon: const Icon(Icons.sort, size: 20),
              itemBuilder: (context) => [
                for (final sort in _DocumentSort.values)
                  PopupMenuItem(value: sort, child: Text(sort.label)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          _ArchiveEmpty(searching: documents.isNotEmpty)
        else
          for (final document in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CosmicColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: CosmicColors.line),
                ),
                child: Row(
                  children: [
                    Icon(
                      document.signed
                          ? Icons.verified_outlined
                          : Icons.picture_as_pdf_outlined,
                      size: 20,
                      color: document.signed
                          ? CosmicColors.accent2
                          : CosmicColors.success,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  document.title,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (document.signed)
                                const _Badge(
                                  text: 'подписан',
                                  color: CosmicColors.accent2,
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${document.number} · '
                            '${formatDateRu(document.createdAt.toLocal())}'
                            '${document.sizeBytes == null ? '' : ' · ${(document.sizeBytes! / 1024).toStringAsFixed(0)} КБ'}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: CosmicColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Открыть PDF',
                      onPressed: document.filePath == null
                          ? null
                          : () => _openDocument(context, document.filePath!),
                      icon: const Icon(Icons.open_in_new, size: 18),
                    ),
                    PopupMenuButton<_DocumentAction>(
                      tooltip: 'Действия с документом',
                      onSelected: (action) => _handle(action, document),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: _DocumentAction.open,
                          enabled: document.filePath != null,
                          child: const Text('Открыть PDF'),
                        ),
                        PopupMenuItem(
                          value: _DocumentAction.share,
                          enabled: document.filePath != null,
                          child: const Text('Поделиться PDF'),
                        ),
                        PopupMenuItem(
                          value: _DocumentAction.toggleSigned,
                          child: Text(
                            document.signed
                                ? 'Снять отметку'
                                : 'Отметить подписанным',
                          ),
                        ),
                        const PopupMenuItem(
                          value: _DocumentAction.delete,
                          child: Text('Удалить'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Future<void> _handle(_DocumentAction action, DocumentRecord document) async {
    switch (action) {
      case _DocumentAction.open:
        final path = document.filePath;
        if (path != null) await _openDocument(context, path);
      case _DocumentAction.share:
        await _shareDocument(context, document);
      case _DocumentAction.toggleSigned:
        await _setSigned(document);
      case _DocumentAction.delete:
        await _delete(document);
    }
  }

  Future<void> _setSigned(DocumentRecord document) async {
    try {
      await ref
          .read(repositoryProvider)
          .setDocumentSigned(document.id, !document.signed);
      ref.invalidate(documentsProvider);
      ref.invalidate(outboxProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            document.signed
                ? 'Отметка о подписании снята'
                : 'Документ отмечен подписанным',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось изменить документ: $error')),
      );
    }
  }

  Future<void> _delete(DocumentRecord document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить документ?'),
        content: Text(
          '${document.title}\n\nФайл PDF останется в хранилище, '
          'но запись исчезнет из архива.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(repositoryProvider).deleteDocument(document.id);
      ref.invalidate(documentsProvider);
      ref.invalidate(outboxProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Документ удалён')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось удалить документ: $error')),
      );
    }
  }
}

class _ArchiveEmpty extends StatelessWidget {
  const _ArchiveEmpty({required this.searching});

  final bool searching;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: CosmicColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CosmicColors.line),
      ),
      child: Column(
        children: [
          Icon(
            searching ? Icons.search_off : Icons.folder_open_outlined,
            size: 36,
            color: CosmicColors.muted,
          ),
          const SizedBox(height: 10),
          Text(
            searching ? 'Ничего не найдено.\nИзмените запрос или сортировку.' : 'Архив пуст.\nСформируйте договор из завершённого мероприятия.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: CosmicColors.muted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _shareDocument(
  BuildContext context,
  DocumentRecord document,
) async {
  final path = document.filePath;
  if (path == null) return;
  try {
    final bytes = await readDocumentBytes(path);
    await Printing.sharePdf(bytes: bytes, filename: '${document.number}.pdf');
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Не удалось поделиться PDF: $error')),
    );
  }
}

Future<void> _openDocument(BuildContext context, String path) async {
  try {
    await openDocument(path);
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Не удалось открыть PDF: $error')));
  }
}

void _openGenerator(
  BuildContext context,
  Company company,
  List<Event> completed,
  _DocumentKind kind,
) {
  showDialog<void>(
    context: context,
    builder: (_) => _GenerateDocumentDialog(
      company: company,
      completedEvents: completed,
      kind: kind,
    ),
  );
}

class _GenerateDocumentDialog extends ConsumerStatefulWidget {
  const _GenerateDocumentDialog({
    required this.company,
    required this.completedEvents,
    this.kind = _DocumentKind.contract,
  });

  final Company company;
  final List<Event> completedEvents;
  final _DocumentKind kind;

  @override
  ConsumerState<_GenerateDocumentDialog> createState() =>
      _GenerateDocumentDialogState();
}

class _GenerateDocumentDialogState
    extends ConsumerState<_GenerateDocumentDialog> {
  Event? _event;
  TemplateRecord? _template;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final templates =
        ref.watch(templatesProvider).valueOrNull ?? const <TemplateRecord>[];
    if (_event == null && widget.completedEvents.isNotEmpty) {
      final latest = [...widget.completedEvents]
        ..sort((a, b) => b.date.compareTo(a.date));
      _event = latest.first;
    }
    if (widget.kind == _DocumentKind.contract &&
        _template == null &&
        templates.isNotEmpty) {
      _template = _matchingTemplate(templates);
    }
    return AlertDialog(
      title: Text(widget.kind.actionTitle),
      content: SizedBox(
        width: 460,
        child: _busy
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Event>(
                    initialValue: _event,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Мероприятие'),
                    items: widget.completedEvents
                        .map(
                          (event) => DropdownMenuItem(
                            value: event,
                            child: Text(
                              '${formatDateShortRu(event.date)} · '
                              '${event.institutionName}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() {
                      _event = value;
                      if (widget.kind == _DocumentKind.contract) {
                        _template = _matchingTemplate(templates);
                      }
                    }),
                  ),
                  if (widget.kind == _DocumentKind.contract) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<TemplateRecord>(
                      initialValue: _template,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Шаблон'),
                      items: templates
                          .map(
                            (template) => DropdownMenuItem(
                              value: template,
                              child: Text(template.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _template = value),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    switch (widget.kind) {
                      _DocumentKind.contract =>
                        'Договор будет сформирован в PDF с подстановкой данных '
                            'мероприятия, реквизитов компании и доли учреждения.',
                      _DocumentKind.act =>
                        'Акт будет сформирован по завершённому мероприятию '
                            'с суммой, долей учреждения и подписями сторон.',
                      _DocumentKind.invoice =>
                        'Счёт будет сформирован с реквизитами исполнителя '
                            'и стоимостью программы. Без НДС (НПД).',
                    },
                    style: const TextStyle(
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
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed:
              _busy ||
                  _event == null ||
                  (widget.kind == _DocumentKind.contract && _template == null)
              ? null
              : _generate,
          child: const Text('Сформировать'),
        ),
      ],
    );
  }

  TemplateRecord? _matchingTemplate(List<TemplateRecord> templates) {
    final event = _event;
    if (event == null) return templates.isEmpty ? null : templates.first;
    final institutions =
        ref.read(institutionsProvider).valueOrNull ?? const <Institution>[];
    InstitutionType type = InstitutionType.kindergarten;
    for (final institution in institutions) {
      if (institution.id == event.institutionId) type = institution.type;
    }
    for (final template in templates) {
      if (template.type == type) return template;
    }
    return templates.isEmpty ? null : templates.first;
  }

  Future<void> _generate() async {
    final event = _event;
    final template = _template;
    if (event == null) return;
    if (widget.kind == _DocumentKind.contract && template == null) return;
    setState(() => _busy = true);
    try {
      final year = DateTime.now().year;
      final documents =
          ref.read(documentsProvider).valueOrNull ?? const <DocumentRecord>[];
      final existing = documents
          .where((document) => document.type == widget.kind.dbType)
          .length;
      final code = widget.company.id == 'c-lunny' ? 'ЛД' : 'СЗ';
      final number =
          'ПЛ-$code-${widget.kind.code}-$year-${(existing + 1).toString().padLeft(4, '0')}';
      final bytes = switch (widget.kind) {
        _DocumentKind.contract => await buildContractPdf(
          company: widget.company,
          event: event,
          templateBody: template!.body,
          documentNumber: number,
        ),
        _DocumentKind.act => await buildActPdf(
          company: widget.company,
          event: event,
          documentNumber: number,
        ),
        _DocumentKind.invoice => await buildInvoicePdf(
          company: widget.company,
          event: event,
          documentNumber: number,
        ),
      };
      final fileName = '$number.pdf';
      if (!mounted) return;
      setState(() => _busy = false);
      final previewed = await showPdfPreview(
        context,
        title: '${widget.kind.title} $number',
        subtitle: '${event.institutionName} · ${formatDateRu(event.date)}',
        bytes: bytes,
        fileName: fileName,
      );
      if (!previewed || !mounted) return;
      final path = await saveDocumentBytes(fileName: fileName, bytes: bytes);
      await ref
          .read(repositoryProvider)
          .addDocument(
            DocumentRecord(
              id: _uuid.v4(),
              companyId: widget.company.id,
              eventId: event.id,
              type: widget.kind.dbType,
              number: number,
              title:
                  '${widget.kind.title} · ${event.institutionName} · ${formatDateRu(event.date)}',
              filePath: path,
              sizeBytes: bytes.length,
              createdAt: DateTime.now(),
            ),
          );
      ref.invalidate(documentsProvider);
      ref.invalidate(outboxProvider);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.kind.title} $number сформирован'
            '${path == null ? ' · ${(bytes.length / 1024).toStringAsFixed(0)} КБ' : ''}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сформировать PDF: $error')),
      );
    }
  }
}

class _SectionHint extends StatelessWidget {
  const _SectionHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        color: CosmicColors.muted,
        height: 1.4,
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, color: color)),
    );
  }
}
