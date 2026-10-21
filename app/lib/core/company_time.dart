import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

bool _initialized = false;

void ensureTimeZones() {
  if (_initialized) return;
  tz_data.initializeTimeZones();
  _initialized = true;
}

DateTime eventStartUtc({
  required String timezone,
  required DateTime date,
  required String timeStart,
  int durationMinutes = 0,
}) {
  ensureTimeZones();
  final parts = timeStart.split(':');
  final hour = int.parse(parts[0]);
  final minute = int.parse(parts[1]);
  final location = tz.getLocation(timezone);
  final local = tz.TZDateTime(
    location,
    date.year,
    date.month,
    date.day,
    hour,
    minute,
  );
  return local.toUtc().add(Duration(minutes: durationMinutes));
}

DateTime eventEndUtc({
  required String timezone,
  required DateTime date,
  required String timeStart,
  required int durationMinutes,
}) => eventStartUtc(
  timezone: timezone,
  date: date,
  timeStart: timeStart,
  durationMinutes: durationMinutes,
);

DateTime todayInCompany(String timezone) {
  ensureTimeZones();
  final now = tz.TZDateTime.now(tz.getLocation(timezone));
  return DateTime(now.year, now.month, now.day);
}

String companyOffsetLabel(String timezone, DateTime at) {
  ensureTimeZones();
  final local = tz.TZDateTime.from(at, tz.getLocation(timezone));
  final offset = local.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final hours = offset.inHours.abs().toString().padLeft(2, '0');
  final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
  return 'UTC$sign$hours:$minutes';
}

String monthKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
