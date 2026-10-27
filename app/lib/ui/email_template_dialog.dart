import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/email_templates.dart';
import '../data/models.dart';
import '../state/providers.dart';
import '../theme.dart';

Future<void> showEmailTemplateDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _EmailTemplateDialog(),
  );
}

class _EmailTemplateDialog extends ConsumerStatefulWidget {
  const _EmailTemplateDialog();

  @override
  ConsumerState<_EmailTemplateDialog> createState() =>
      _EmailTemplateDialogState();
}

class _EmailTemplateDialogState extends ConsumerState<_EmailTemplateDialog> {
  final _subject = TextEditingController();
  final _body = TextEditingController();
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final company = ref.read(sessionProvider).company;
    if (company == null) return;
    final template = await loadEmailTemplate(
      ref.read(repositoryProvider),
      company,
    );
    if (!mounted) return;
    _subject.text = template.subject;
    _body.text = template.body;
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final company = ref.read(sessionProvider).company;
    if (company == null) return;
    final subject = _subject.text.trim();
    final body = _body.text.trim();
    if (subject.isEmpty || body.isEmpty) {
      setState(() => _error = 'Заполните тему и текст письма');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    await saveEmailTemplate(
      ref.read(repositoryProvider),
      company,
      EmailTemplate(subject: subject, body: body),
    );
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Шаблон письма сохранён')));
  }

  void _reset() {
    final company = ref.read(sessionProvider).company;
    if (company == null) return;
    final defaults = defaultEmailTemplate(company);
    _subject.text = defaults.subject;
    _body.text = defaults.body;
    setState(() => _error = null);
  }

  void _insert(TextEditingController controller, String token) {
    final text = controller.text;
    final selection = controller.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    controller.value = TextEditingValue(
      text: text.replaceRange(start, end, token),
      selection: TextSelection.collapsed(offset: start + token.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final company = ref.watch(sessionProvider).company;
    final institutions =
        ref.watch(institutionsProvider).valueOrNull ?? const <Institution>[];
    final sample = institutions.isEmpty ? null : institutions.first;
    final previewSubject = sample == null || company == null
        ? _subject.text
        : fillEmailTemplate(
            _subject.text,
            company: company,
            institution: sample,
          );
    final previewBody = sample == null || company == null
        ? _body.text
        : fillEmailTemplate(_body.text, company: company, institution: sample);
    return AlertDialog(
      title: const Text('Шаблон письма'),
      content: SizedBox(
        width: 380,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _subject,
                      decoration: const InputDecoration(
                        labelText: 'Тема письма',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _body,
                      minLines: 8,
                      maxLines: 14,
                      decoration: const InputDecoration(
                        labelText: 'Текст письма',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Переменные',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: CosmicColors.text2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final entry in emailPlaceholders.entries)
                          ActionChip(
                            label: Text(
                              entry.key,
                              style: const TextStyle(fontSize: 11),
                            ),
                            onPressed: () => _insert(_body, entry.key),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      title: const Text(
                        'Предпросмотр',
                        style: TextStyle(fontSize: 13),
                      ),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            previewSubject,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            previewBody,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: CosmicColors.danger,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : _reset,
          child: const Text('Сбросить'),
        ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _busy || _loading ? null : _save,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
