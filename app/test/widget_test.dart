import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planetarium_manager/app.dart';
import 'package:planetarium_manager/core/company_time.dart';
import 'package:planetarium_manager/core/pin.dart';
import 'package:planetarium_manager/core/ru_format.dart';
import 'package:planetarium_manager/data/memory_repository.dart';
import 'package:planetarium_manager/state/providers.dart';

void main() {
  testWidgets('выбор компании открывает главную', (tester) async {
    await ensureRussianLocale();
    ensureTimeZones();
    final repository = await MemoryRepository.create();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repository)],
        child: const PlanetariumApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Выберите\nпланетарий'), findsOneWidget);
    expect(find.text('Планетарий «Лунный Дом»'), findsOneWidget);
    expect(find.text('Планетарий «Созвездие»'), findsOneWidget);

    final selectButtons = find.widgetWithText(FilledButton, 'Выбрать');
    expect(selectButtons, findsNWidgets(2));
    await tester.ensureVisible(selectButtons.first);
    await tester.tap(selectButtons.first);
    await tester.pumpAndSettle();

    expect(find.text('Главная'), findsOneWidget);
    expect(find.text('Марина'), findsOneWidget);
    expect(find.text('Расписание'), findsOneWidget);
    expect(find.text('Выручка'), findsWidgets);
  });

  testWidgets('расписание показывает карточку мероприятия', (tester) async {
    await ensureRussianLocale();
    ensureTimeZones();
    final repository = await MemoryRepository.create();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repository)],
        child: const PlanetariumApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Выбрать').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Расписание').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('22').first);
    await tester.pumpAndSettle();

    final title = find.text('Детский сад №23');
    expect(title, findsOneWidget);
    expect(tester.getSize(title).height, greaterThan(0));

    await tester.enterText(find.byType(TextField), 'Детский сад №23');
    await tester.pumpAndSettle();
    expect(find.textContaining('Ничего не найдено'), findsNothing);

    await tester.enterText(find.byType(TextField), 'нет такого учреждения');
    await tester.pumpAndSettle();
    expect(find.textContaining('Ничего не найдено'), findsOneWidget);
  });

  testWidgets('архив предлагает шаблон договора', (tester) async {
    await ensureRussianLocale();
    ensureTimeZones();
    final repository = await MemoryRepository.create();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repository)],
        child: const PlanetariumApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Выбрать').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Документы').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Архив'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Договор'));
    await tester.pumpAndSettle();

    final generate = find.widgetWithText(FilledButton, 'Сформировать');
    expect(generate, findsOneWidget);
    expect(tester.widget<FilledButton>(generate).onPressed, isNotNull);
  });

  testWidgets('переключение вкладок не падает', (tester) async {
    await ensureRussianLocale();
    ensureTimeZones();
    final repository = await MemoryRepository.create();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repository)],
        child: const PlanetariumApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Выбрать').first);
    await tester.pumpAndSettle();

    for (final label in ['Расписание', 'База', 'Документы', 'Выручка']) {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('база фильтрует по тегу и меняет статус массово', (tester) async {
    await ensureRussianLocale();
    ensureTimeZones();
    final repository = await MemoryRepository.create();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repository)],
        child: const PlanetariumApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Выбрать').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('База').last);
    await tester.pumpAndSettle();

    expect(find.text('Найдено: 5'), findsOneWidget);
    await tester.tap(find.text('Тег'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('частный').last);
    await tester.pumpAndSettle();
    expect(find.text('Найдено: 1'), findsOneWidget);

    await tester.tap(find.byType(Chip).at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Все: Тег').last);
    await tester.pumpAndSettle();
    expect(find.text('Найдено: 5'), findsOneWidget);

    await tester.tap(find.byTooltip('Выбрать несколько'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();
    expect(find.text('Выбрано: 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Отметить проверенными'));
    await tester.pumpAndSettle();
    expect(find.textContaining('установлен: 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Фильтр по статусу'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Проверено').last);
    await tester.pumpAndSettle();
    expect(find.text('Найдено: 3'), findsOneWidget);

    await tester.tap(find.byTooltip('Фильтр по статусу'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Все статусы').last);
    await tester.pumpAndSettle();
    expect(find.text('Найдено: 5'), findsOneWidget);
  });

  testWidgets('PIN запрашивается при запуске и открывает приложение', (
    tester,
  ) async {
    await ensureRussianLocale();
    ensureTimeZones();
    final repository = await MemoryRepository.create();
    final stored = hashPinPbkdf2('4271', iterations: 1000);
    await repository.setSetting(pinHashKey, stored.hash);
    await repository.setSetting(pinSaltKey, stored.salt);
    await repository.setSetting(pinIterationsKey, '${stored.iterations}');
    await repository.setSetting(pinAlgorithmKey, stored.algorithm);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repository)],
        child: const PlanetariumApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Приложение защищено PIN-кодом'), findsOneWidget);
    expect(find.text('Выберите\nпланетарий'), findsNothing);

    await tester.enterText(find.byType(TextField), '1111');
    await tester.tap(find.widgetWithText(FilledButton, 'Открыть'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Неверный PIN'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '4271');
    await tester.tap(find.widgetWithText(FilledButton, 'Открыть'));
    await tester.pumpAndSettle();
    expect(find.text('Выберите\nпланетарий'), findsOneWidget);
  });

  testWidgets('меню открывает резервную копию', (tester) async {
    await ensureRussianLocale();
    ensureTimeZones();
    final repository = await MemoryRepository.create();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repository)],
        child: const PlanetariumApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Выбрать').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Показать меню'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Резервная копия'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('доступна в приложении на устройстве'),
      findsOneWidget,
    );
    final save = find.widgetWithText(FilledButton, 'Сохранить копию');
    expect(save, findsOneWidget);
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
  });

  testWidgets('напоминания доступны только на устройстве', (tester) async {
    await ensureRussianLocale();
    ensureTimeZones();
    final repository = await MemoryRepository.create();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repository)],
        child: const PlanetariumApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Выбрать').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Показать меню'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Напоминания'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('доступны в приложении на устройстве'),
      findsOneWidget,
    );
    final toggle = find.byType(Switch);
    expect(toggle, findsOneWidget);
    expect(tester.widget<Switch>(toggle).onChanged, isNull);
  });
}
