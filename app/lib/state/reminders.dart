import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/reminders.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../services/notification_service.dart';
import 'providers.dart';

Future<int> syncAllReminders(Repository repository) async {
  final enabled = await repository.setting(notificationsEnabledKey, '0') == '1';
  if (!enabled) {
    await NotificationService.cancelAll();
    return 0;
  }
  final leadMinutes =
      int.tryParse(
        await repository.setting(
          notificationLeadKey,
          '$defaultNotificationLeadMinutes',
        ),
      ) ??
      defaultNotificationLeadMinutes;
  final events = <Event>[];
  for (final company in await repository.companies()) {
    events.addAll(await repository.events(company.id));
  }
  final reminders = planReminders(
    events: events,
    leadMinutes: leadMinutes,
    nowUtc: DateTime.now().toUtc(),
  );
  return NotificationService.replaceReminders(
    reminders,
    leadMinutes: leadMinutes,
  );
}

Future<void> refreshReminders(WidgetRef ref) async {
  try {
    await syncAllReminders(ref.read(repositoryProvider));
  } catch (_) {
    // Напоминания не должны блокировать основные действия с данными.
  }
}
