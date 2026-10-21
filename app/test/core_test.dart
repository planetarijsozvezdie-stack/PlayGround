import 'package:flutter_test/flutter_test.dart';
import 'package:planetarium_manager/core/company_time.dart';
import 'package:planetarium_manager/core/event_rules.dart';
import 'package:planetarium_manager/core/money.dart';
import 'package:planetarium_manager/core/pin.dart';
import 'package:planetarium_manager/core/pricing.dart';
import 'package:planetarium_manager/core/reminders.dart';
import 'package:planetarium_manager/core/ru_format.dart';
import 'package:planetarium_manager/core/tax.dart';
import 'package:planetarium_manager/data/models.dart';

void main() {
  group('roundHalfUpDiv', () {
    test('округляет половину вверх', () {
      expect(roundHalfUpDiv(1, 2), 1);
      expect(roundHalfUpDiv(3, 2), 2);
      expect(roundHalfUpDiv(5, 2), 3);
      expect(roundHalfUpDiv(1, 3), 0);
      expect(roundHalfUpDiv(2, 3), 1);
    });
  });

  group('pluralRu', () {
    test('русские формы для детей', () {
      expect(childrenCountLabel(1), '1 ребёнок');
      expect(childrenCountLabel(2), '2 ребёнка');
      expect(childrenCountLabel(5), '5 детей');
      expect(childrenCountLabel(11), '11 детей');
      expect(childrenCountLabel(21), '21 ребёнок');
      expect(childrenCountLabel(22), '22 ребёнка');
      expect(childrenCountLabel(25), '25 детей');
    });

    test('программы, сеансы и документы', () {
      expect(programsCountLabel(1), '1 программа');
      expect(programsCountLabel(4), '4 программы');
      expect(programsCountLabel(12), '12 программ');
      expect(sessionsCountLabel(2), '2 сеанса');
      expect(sessionsCountLabel(9), '9 сеансов');
      expect(documentsCountLabel(1), '1 документ');
      expect(documentsCountLabel(3), '3 документа');
    });
  });

  group('EventPricing', () {
    test('25 детей × 250 ₽, доля 25%', () {
      final pricing = EventPricing.compute(
        childrenCount: 25,
        pricePerChildKopecks: 25000,
        institutionPercentBp: 2500,
      );
      expect(pricing.grossKopecks, 625000);
      expect(pricing.institutionShareKopecks, 156250);
      expect(pricing.netKopecks, 468750);
      expect(
        pricing.grossKopecks,
        pricing.institutionShareKopecks + pricing.netKopecks,
      );
    });

    test('доля 0% и 100%', () {
      final zero = EventPricing.compute(
        childrenCount: 10,
        pricePerChildKopecks: 25000,
        institutionPercentBp: 0,
      );
      expect(zero.institutionShareKopecks, 0);
      expect(zero.netKopecks, 250000);

      final full = EventPricing.compute(
        childrenCount: 10,
        pricePerChildKopecks: 25000,
        institutionPercentBp: 10000,
      );
      expect(full.institutionShareKopecks, 250000);
      expect(full.netKopecks, 0);
    });
  });

  group('TaxCalculator', () {
    test('6% для юрлица с вычетом 2%', () {
      final result = TaxCalculator.calculate(
        taxBaseKopecks: 468750,
        counterparty: CounterpartyType.legal,
        deductionRemainingKopecks: TaxCalculator.deductionLimitKopecks,
      );
      expect(result.rateBp, 600);
      expect(result.deductionAppliedKopecks, 9375);
      expect(result.taxAmountKopecks, 18750);
      expect(result.deductionRemainingKopecks, 990625);
    });

    test('4% для физлица с вычетом 1%', () {
      final result = TaxCalculator.calculate(
        taxBaseKopecks: 100000,
        counterparty: CounterpartyType.individual,
        deductionRemainingKopecks: TaxCalculator.deductionLimitKopecks,
      );
      expect(result.rateBp, 400);
      expect(result.deductionAppliedKopecks, 1000);
      expect(result.taxAmountKopecks, 3000);
    });

    test('вычет расходуется частично и не уходит в минус', () {
      final result = TaxCalculator.calculate(
        taxBaseKopecks: 100000,
        counterparty: CounterpartyType.legal,
        deductionRemainingKopecks: 500,
      );
      expect(result.deductionAppliedKopecks, 500);
      expect(result.taxAmountKopecks, 5500);
      expect(result.deductionRemainingKopecks, 0);

      final exhausted = TaxCalculator.calculate(
        taxBaseKopecks: 100000,
        counterparty: CounterpartyType.legal,
        deductionRemainingKopecks: 0,
      );
      expect(exhausted.taxAmountKopecks, 6000);
    });

    test('addDeductionUsed ограничивает лимитом', () {
      expect(
        addDeductionUsed(999000, 5000),
        TaxCalculator.deductionLimitKopecks,
      );
      expect(addDeductionUsed(100, 200), 300);
    });
  });

  group('EventRules', () {
    test('завершение создаёт авто-начисление или задачу', () {
      expect(
        EventRules.onStatusChange(EventStatus.scheduled, EventStatus.completed),
        RevenueEffect.createAuto,
      );
      expect(
        EventRules.onStatusChange(
          EventStatus.scheduled,
          EventStatus.completed,
          mode: RevenueMode.confirm,
        ),
        RevenueEffect.createConfirmationTask,
      );
    });

    test('отмена и возврат завершённого делают сторно', () {
      expect(
        EventRules.onStatusChange(EventStatus.completed, EventStatus.cancelled),
        RevenueEffect.reverseAuto,
      );
      expect(
        EventRules.onStatusChange(EventStatus.completed, EventStatus.scheduled),
        RevenueEffect.reverseAuto,
      );
      expect(
        EventRules.onStatusChange(EventStatus.scheduled, EventStatus.cancelled),
        RevenueEffect.none,
      );
      expect(
        EventRules.onStatusChange(EventStatus.scheduled, EventStatus.scheduled),
        RevenueEffect.none,
      );
    });
  });

  group('CompanyTime', () {
    setUpAll(ensureTimeZones);

    test('Уфа UTC+5, Нижний Новгород UTC+3', () {
      expect(
        eventStartUtc(
          timezone: 'Asia/Yekaterinburg',
          date: DateTime(2026, 10, 12),
          timeStart: '09:00',
        ),
        DateTime.utc(2026, 10, 12, 4),
      );
      expect(
        eventStartUtc(
          timezone: 'Europe/Moscow',
          date: DateTime(2026, 10, 12),
          timeStart: '09:00',
        ),
        DateTime.utc(2026, 10, 12, 6),
      );
    });

    test('длительность прибавляется к UTC-старту', () {
      expect(
        eventEndUtc(
          timezone: 'Asia/Yekaterinburg',
          date: DateTime(2026, 10, 12),
          timeStart: '09:00',
          durationMinutes: 40,
        ),
        DateTime.utc(2026, 10, 12, 4, 40),
      );
    });

    test('подпись смещения', () {
      expect(
        companyOffsetLabel('Asia/Yekaterinburg', DateTime.utc(2026, 10, 12)),
        'UTC+05:00',
      );
      expect(
        companyOffsetLabel('Europe/Moscow', DateTime.utc(2026, 10, 12)),
        'UTC+03:00',
      );
    });
  });

  group('PIN', () {
    test('Argon2id проверяет верный PIN и отвергает неверный', () async {
      final stored = await hashPin('4271');
      expect(stored.hash, isNot(contains('4271')));
      expect(stored.algorithm, pinAlgorithmArgon2id);
      expect(await verifyPin('4271', stored), isTrue);
      expect(await verifyPin('4272', stored), isFalse);
      expect(await verifyPin('121', stored), isFalse);
    });

    test('соль делает хеши одинаковых PIN разными', () async {
      final first = await hashPin('1234');
      final second = await hashPin('1234');
      expect(first.salt, isNot(second.salt));
      expect(first.hash, isNot(second.hash));
    });

    test('старый PBKDF2-хеш проверяется и требует обновления', () async {
      final legacy = hashPinPbkdf2('4271', iterations: 1000);
      expect(legacy.needsRehash, isTrue);
      expect(await verifyPin('4271', legacy), isTrue);
      expect(await verifyPin('0000', legacy), isFalse);
    });

    test('допустимая длина PIN 4–6 цифр', () {
      expect(isValidPin('1234'), isTrue);
      expect(isValidPin('123456'), isTrue);
      expect(isValidPin('123'), isFalse);
      expect(isValidPin('1234567'), isFalse);
      expect(isValidPin('12a4'), isFalse);
    });
  });

  group('Напоминания', () {
    Event event({
      String id = 'e-reminder',
      DateTime? date,
      String time = '09:00',
      EventStatus status = EventStatus.scheduled,
    }) => Event(
      id: id,
      companyId: 'c-lunny',
      institutionId: 'i-1',
      institutionName: 'Детский сад №23',
      institutionAddress: 'Уфа, ул. Лучевая, д. 3',
      contactPerson: 'Иванова',
      contactPhone: '+7 999 000-00-00',
      date: date ?? DateTime(2026, 10, 22),
      timeStart: time,
      durationMinutes: 40,
      timezone: 'Asia/Yekaterinburg',
      programName: 'Космическое путешествие',
      childrenCount: 22,
      pricePerChildKopecks: 25000,
      institutionPercentBp: 2000,
      grossKopecks: 550000,
      institutionShareKopecks: 110000,
      netKopecks: 440000,
      status: status,
      notes: '',
      googleEventId: null,
    );

    test('планирует только будущие запланированные мероприятия', () {
      final now = DateTime.utc(2026, 10, 21, 12);
      final reminders = planReminders(
        events: [
          event(),
          event(id: 'past', date: DateTime(2026, 10, 20)),
          event(id: 'done', status: EventStatus.completed),
          event(id: 'far', date: DateTime(2027, 1, 1)),
        ],
        leadMinutes: 60,
        nowUtc: now,
      );
      expect(reminders.length, 1);
      expect(reminders.first.event.id, 'e-reminder');
      expect(reminders.first.fireAtUtc, DateTime.utc(2026, 10, 22, 3));
    });

    test('время напоминания зависит от часового пояса', () {
      final now = DateTime.utc(2026, 10, 21, 12);
      final start = eventStartUtc(
        timezone: 'Asia/Yekaterinburg',
        date: DateTime(2026, 10, 22),
        timeStart: '09:00',
      );
      expect(start, DateTime.utc(2026, 10, 22, 4));
      final reminders = planReminders(
        events: [event()],
        leadMinutes: 120,
        nowUtc: now,
      );
      expect(reminders.single.fireAtUtc, DateTime.utc(2026, 10, 22, 2));
    });

    test('подписи интервала и текст уведомления', () {
      expect(notificationLeadLabel(15), 'За 15 минут');
      expect(notificationLeadLabel(60), 'За 1 час');
      expect(notificationLeadLabel(120), 'За 2 часа');
      expect(notificationLeadLabel(1440), 'За 1 день');
      final reminder = PlannedReminder(
        event: event(),
        fireAtUtc: DateTime.utc(2026, 10, 22, 3),
      );
      expect(reminderTitle(reminder, 60), 'Мероприятие за 1 час');
      expect(reminderBody(reminder.event), contains('Детский сад №23'));
      expect(reminderBody(reminder.event), contains('22 ребёнка'));
    });
  });
}
