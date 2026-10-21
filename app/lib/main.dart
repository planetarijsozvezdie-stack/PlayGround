import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/company_time.dart';
import 'core/ru_format.dart';
import 'data/repository.dart';
import 'data/repository_factory.dart';
import 'services/notification_service.dart';
import 'state/providers.dart';
import 'state/reminders.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ensureRussianLocale();
  ensureTimeZones();
  final repository = await createRepository();
  try {
    await NotificationService.initialize();
  } catch (_) {}
  unawaited(_syncReminders(repository));
  runApp(
    ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(repository)],
      child: const PlanetariumApp(),
    ),
  );
}

Future<void> _syncReminders(Repository repository) async {
  try {
    await syncAllReminders(repository);
  } catch (_) {}
}
