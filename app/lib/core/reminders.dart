import '../data/models.dart';
import 'event_rules.dart';
import 'company_time.dart';
import 'ru_format.dart';

const notificationsEnabledKey = 'notifications_enabled';
const notificationLeadKey = 'notification_lead_minutes';
const defaultNotificationLeadMinutes = 60;

const notificationLeadOptions = [15, 30, 60, 120, 1440];

String notificationLeadLabel(int minutes) {
  if (minutes >= 1440) {
    final days = minutes ~/ 1440;
    return days == 1 ? 'За 1 день' : 'За $days дня';
  }
  if (minutes >= 60) {
    final hours = minutes ~/ 60;
    return hours == 1 ? 'За 1 час' : 'За $hours часа';
  }
  return 'За $minutes минут';
}

class PlannedReminder {
  const PlannedReminder({required this.event, required this.fireAtUtc});

  final Event event;
  final DateTime fireAtUtc;
}

List<PlannedReminder> planReminders({
  required Iterable<Event> events,
  required int leadMinutes,
  required DateTime nowUtc,
  int horizonDays = 60,
}) {
  final horizon = nowUtc.add(Duration(days: horizonDays));
  final result = <PlannedReminder>[];
  for (final event in events) {
    if (event.status != EventStatus.scheduled) continue;
    final start = eventStartUtc(
      timezone: event.timezone,
      date: event.date,
      timeStart: event.timeStart,
    );
    final fireAt = start.subtract(Duration(minutes: leadMinutes));
    if (!fireAt.isAfter(nowUtc) || fireAt.isAfter(horizon)) continue;
    result.add(PlannedReminder(event: event, fireAtUtc: fireAt));
  }
  result.sort((a, b) => a.fireAtUtc.compareTo(b.fireAtUtc));
  return result;
}

String reminderTitle(PlannedReminder reminder, int leadMinutes) =>
    'Мероприятие ${notificationLeadLabel(leadMinutes).toLowerCase()}';

String reminderBody(Event event) {
  final time = event.timeStart;
  return '${event.institutionName} · $time\n'
      '${event.programName} · ${childrenCountLabel(event.childrenCount)}';
}
