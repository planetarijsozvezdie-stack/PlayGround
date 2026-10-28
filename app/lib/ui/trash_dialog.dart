import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ru_format.dart';
import '../data/models.dart';
import '../state/providers.dart';
import '../theme.dart';

Future<void> showTrashDialog(
  BuildContext context,
  WidgetRef ref,
  String companyId,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => _TrashDialog(companyId: companyId),
  );
}

Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  String action = 'Удалить',
}) async {
  final controller = TextEditingController();
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Введите УДАЛИТЬ',
                  hintText: 'УДАЛИТЬ',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: CosmicColors.danger),
            onPressed: controller.text.trim() == 'УДАЛИТЬ'
                ? () => Navigator.pop(dialogContext, true)
                : null,
            child: Text(action),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  return result ?? false;
}

class _TrashDialog extends ConsumerStatefulWidget {
  const _TrashDialog({required this.companyId});

  final String companyId;

  @override
  ConsumerState<_TrashDialog> createState() => _TrashDialogState();
}

class _TrashDialogState extends ConsumerState<_TrashDialog> {
  List<TrashEntry> _entries = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await ref.read(repositoryProvider).trash(widget.companyId);
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _restore(TrashEntry entry) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(repositoryProvider).restoreTrash(entry.kind, entry.id);
      invalidateBusinessData(ref);
      await _load();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось восстановить: запись с такими же данными уже существует';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _purge() async {
    if (_busy) return;
    final confirmed = await confirmDestructive(
      context,
      title: 'Очистить корзину?',
      message:
          'Записи будут удалены без возможности восстановления. '
          'Связанные данные также будут затронуты.',
      action: 'Очистить',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(repositoryProvider).purgeTrash(widget.companyId);
      invalidateBusinessData(ref);
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Корзина · ${_entries.length}'),
      content: SizedBox(
        width: 480,
        height: 380,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _entries.isEmpty
            ? const Center(
                child: Text(
                  'Корзина пуста',
                  style: TextStyle(color: CosmicColors.muted),
                ),
              )
            : ListView.separated(
                itemCount: _entries.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = _entries[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(switch (entry.kind) {
                      TrashKind.institution => Icons.menu_book_outlined,
                      TrashKind.event => Icons.event_outlined,
                      TrashKind.document => Icons.description_outlined,
                    }),
                    title: Text(entry.title, maxLines: 1),
                    subtitle: Text(
                      '${entry.kind.label} · ${entry.subtitle} · '
                      '${formatDateShortRu(entry.deletedAt.toLocal())}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      tooltip: 'Восстановить',
                      onPressed: _busy ? null : () => _restore(entry),
                      icon: const Icon(Icons.restore),
                    ),
                  );
                },
              ),
      ),
      actions: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              _error!,
              style: const TextStyle(fontSize: 12, color: CosmicColors.danger),
            ),
          ),
        TextButton(
          onPressed: _entries.isEmpty || _busy ? null : _purge,
          style: TextButton.styleFrom(foregroundColor: CosmicColors.danger),
          child: const Text('Очистить корзину'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }
}
