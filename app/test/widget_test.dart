import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planetarium_manager/app.dart';
import 'package:planetarium_manager/core/company_time.dart';
import 'package:planetarium_manager/core/email_templates.dart';
import 'package:planetarium_manager/core/pin.dart';
import 'package:planetarium_manager/core/ru_format.dart';
import 'package:planetarium_manager/data/memory_repository.dart';
import 'package:planetarium_manager/data/models.dart';
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
    await tester.tap(find.byTooltip('Вперёд'));
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

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Вид'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('месяц').last);
    await tester.pumpAndSettle();
    expect(find.text('месяц'), findsOneWidget);
  });

  testWidgets('выручка показывает сравнения, 30 дней и компании', (
    tester,
  ) async {
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
    await tester.tap(find.text('Выручка').last);
    await tester.pumpAndSettle();

    expect(find.text('ВЫРУЧКА ЗА МЕСЯЦ'), findsOneWidget);
    expect(find.text('СЕГОДНЯ'), findsOneWidget);
    expect(find.text('ГОД'), findsOneWidget);

    final revenueList = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Последние 30 дней'),
      200,
      scrollable: revenueList,
    );
    await tester.pumpAndSettle();
    expect(find.text('Последние 30 дней'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Выручка по компаниям'),
      200,
      scrollable: revenueList,
    );
    await tester.pumpAndSettle();
    expect(find.text('Выручка по компаниям'), findsOneWidget);
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
    expect(find.byTooltip('Только подписанные'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Договор'));
    await tester.pumpAndSettle();

    final generate = find.widgetWithText(FilledButton, 'Сформировать');
    expect(generate, findsOneWidget);
    expect(tester.widget<FilledButton>(generate).onPressed, isNotNull);
  });

  testWidgets('архив фильтрует подписанные документы', (tester) async {
    await ensureRussianLocale();
    ensureTimeZones();
    final repository = await MemoryRepository.create();
    await repository.addDocument(
      DocumentRecord(
        id: 'doc-signed',
        companyId: 'c-lunny',
        eventId: null,
        type: 'contract',
        number: 'ПЛ-ЛД-Д-2026-0001',
        title: 'Подписанный договор',
        filePath: null,
        sizeBytes: 1024,
        createdAt: DateTime(2026, 10, 20),
      ),
    );
    await repository.setDocumentSigned('doc-signed', true);
    await repository.addDocument(
      DocumentRecord(
        id: 'doc-draft',
        companyId: 'c-lunny',
        eventId: null,
        type: 'act',
        number: 'ПЛ-ЛД-А-2026-0002',
        title: 'Черновик акта',
        filePath: null,
        sizeBytes: 1024,
        createdAt: DateTime(2026, 10, 21),
      ),
    );

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

    expect(find.text('Подписанный договор'), findsOneWidget);
    expect(find.text('Черновик акта'), findsOneWidget);
    await tester.tap(find.byTooltip('Только подписанные'));
    await tester.pumpAndSettle();
    expect(find.text('Подписанный договор'), findsOneWidget);
    expect(find.text('Черновик акта'), findsNothing);
  });

  testWidgets('шаблон договора редактируется и сохраняется', (tester) async {
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
    await tester.tap(find.text('Шаблоны'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Редактировать').first);
    await tester.pumpAndSettle();
    final editor = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    expect(editor, findsOneWidget);
    await tester.enterText(editor, 'Новый текст {{institution_name}}');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Предпросмотр'));
    await tester.pumpAndSettle();
    final preview = tester.widget<SelectableText>(
      find.byType(SelectableText).last,
    );
    expect(preview.data, contains('Новый текст'));
    expect(preview.data, isNot(contains('{{institution_name}}')));

    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('Шаблон сохранён'), findsOneWidget);
    final templates = await repository.templates('c-lunny');
    expect(
      templates.any(
        (template) => template.body == 'Новый текст {{institution_name}}',
      ),
      isTrue,
    );
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

    await tester.tap(find.byTooltip('Табличный вид'));
    await tester.pumpAndSettle();
    expect(find.text('Сеансы'), findsOneWidget);
    expect(find.text('Был'), findsOneWidget);
    await tester.tap(find.byTooltip('Карточки'));
    await tester.pumpAndSettle();

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

  testWidgets('демо-календарь синхронизирует и удаляет события', (
    tester,
  ) async {
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
    await tester.tap(find.text('Google Календарь'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Демо-режим'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.textContaining('Событий в календаре:'), findsOneWidget);

    final simulate = find.widgetWithText(TextButton, 'Имитировать удаление');
    expect(tester.widget<TextButton>(simulate).onPressed, isNotNull);
    await tester.tap(simulate);
    await tester.pumpAndSettle();
    expect(find.textContaining('Удалено из демо-Google:'), findsOneWidget);
  });

  testWidgets('демо-Диск показывает папку и кнопки выгрузки', (tester) async {
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
    await tester.tap(find.text('Google Диск'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Демо-режим'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.textContaining('Папка: /Планетарий/'), findsOneWidget);
    expect(find.textContaining('Локальных документов:'), findsOneWidget);
    final documents = find.widgetWithText(TextButton, 'Документы');
    expect(tester.widget<TextButton>(documents).onPressed, isNotNull);
    final backup = find.widgetWithText(TextButton, 'Копия');
    expect(tester.widget<TextButton>(backup).onPressed, isNull);
  });

  testWidgets('демо-Таблицы выгружают базу и финансы', (tester) async {
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
    await tester.tap(find.text('Google Таблицы'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Демо-режим'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    final export = find.widgetWithText(TextButton, 'Выгрузить всё');
    expect(tester.widget<TextButton>(export).onPressed, isNotNull);
    await tester.tap(export);
    await tester.pumpAndSettle();

    expect(find.text('Выгружено листов: 2'), findsOneWidget);
    expect(find.textContaining('Учреждения:'), findsOneWidget);
    expect(find.textContaining('Выручка:'), findsOneWidget);
  });

  testWidgets('шаблон письма редактируется и сохраняется', (tester) async {
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
    await tester.tap(find.text('Шаблон письма'));
    await tester.pumpAndSettle();

    expect(find.text('Тема письма'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Индивидуальная тема');
    await tester.enterText(
      find.byType(TextField).last,
      'Текст для {{учреждение}}',
    );
    final save = find.widgetWithText(FilledButton, 'Сохранить');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.text('Шаблон письма сохранён'), findsOneWidget);
    expect(
      await repository.setting(emailTemplateSubjectKey('c-lunny'), ''),
      'Индивидуальная тема',
    );
    expect(
      await repository.setting(emailTemplateBodyKey('c-lunny'), ''),
      'Текст для {{учреждение}}',
    );
  });
}
