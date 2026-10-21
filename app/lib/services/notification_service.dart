import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/reminders.dart';
import '../ui/device_platform.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (!notificationsSupported || _initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_planetarium'),
    );
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  static Future<bool> requestPermission() async {
    if (!notificationsSupported) return false;
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return true;
    final granted = await android.requestNotificationsPermission();
    return granted ?? true;
  }

  static Future<int> replaceReminders(
    List<PlannedReminder> reminders, {
    required int leadMinutes,
  }) async {
    if (!notificationsSupported) return 0;
    await initialize();
    await _plugin.cancelAll();
    var scheduled = 0;
    for (final reminder in reminders) {
      try {
        await _plugin.zonedSchedule(
          id: notificationId(reminder.event.id),
          title: reminderTitle(reminder, leadMinutes),
          body: reminderBody(reminder.event),
          scheduledDate: tz.TZDateTime.from(reminder.fireAtUtc, tz.UTC),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'event_reminders',
              'Напоминания о мероприятиях',
              channelDescription: 'Напоминания о запланированных мероприятиях',
              icon: 'ic_stat_planetarium',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: reminder.event.id,
        );
        scheduled++;
      } catch (error) {
        debugPrint('Не удалось запланировать напоминание: $error');
      }
    }
    return scheduled;
  }

  static Future<void> cancelAll() async {
    if (!notificationsSupported) return;
    await initialize();
    await _plugin.cancelAll();
  }
}

int notificationId(String eventId) {
  var hash = 0x811c9dc5;
  for (final unit in eventId.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}
