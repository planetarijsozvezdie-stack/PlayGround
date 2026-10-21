import '../core/event_rules.dart';
import '../core/tax.dart';
import 'models.dart';

class SeedBundle {
  const SeedBundle({
    required this.companies,
    required this.institutions,
    required this.programs,
    required this.templates,
    required this.events,
  });

  final List<Company> companies;
  final List<Institution> institutions;
  final List<ProgramRecord> programs;
  final List<TemplateRecord> templates;
  final List<SeedEvent> events;
}

class SeedEvent {
  const SeedEvent(this.event, this.finalStatus);

  final Event event;
  final EventStatus finalStatus;
}

const _templateBody = '''
ДОГОВОР ВОЗМЕЗДНОГО ОКАЗАНИЯ УСЛУГ № {{document_number}}

г. {{company_city}}                                                    {{document_date}}

{{company_name}}, ИНН {{company_inn}}, ОГРНИП {{company_ogrnip}}, в лице {{company_signer}}, именуемое в дальнейшем «Исполнитель», с одной стороны, и {{institution_name}}, именуемое в дальнейшем «Заказчик», в лице {{institution_contact}}, с другой стороны, заключили настоящий договор о нижеследующем.

1. ПРЕДМЕТ ДОГОВОРА
1.1. Исполнитель обязуется провести выездную программу «{{program_name}}» {{event_date}} в {{event_time}} по адресу: {{institution_address}}.
1.2. Количество детей: {{children_count}} человек.
1.3. Продолжительность программы: {{duration}} минут.

2. СТОИМОСТЬ И ПОРЯДОК РАСЧЁТОВ
2.1. Стоимость участия одного ребёнка составляет {{price}} ₽.
2.2. Общая стоимость услуг составляет {{gross}} ₽.
2.3. Вознаграждение Заказчика составляет {{institution_share}} ₽ ({{institution_percent}}%).
2.4. Сумма к перечислению Исполнителю: {{net}} ₽.

3. ПРОЧИЕ УСЛОВИЯ
3.1. Исполнитель применяет специальный налоговый режим «Налог на профессиональный доход».
3.2. Договор вступает в силу с момента подписания и действует до полного исполнения обязательств.

ИСПОЛНИТЕЛЬ: {{company_name}}          ЗАКАЗЧИК: {{institution_name}}
{{company_signer}}                      {{institution_contact}}

_____________________                   _____________________
''';

SeedBundle buildSeedBundle({DateTime? now}) {
  final today = now ?? DateTime.now();
  final companies = [
    const Company(
      id: 'c-lunny',
      name: 'Планетарий «Лунный Дом»',
      shortName: 'Лунный Дом',
      city: 'Уфа',
      region: 'Республика Башкортостан',
      timezone: 'Asia/Yekaterinburg',
      inn: '027812345678',
      ogrnip: '321028000012345',
      legalAddress: '450000, г. Уфа, ул. Космическая, 12, офис 4',
      bankDetails: 'ООО «Банк Урал» · р/с 40802810400000123456',
      phone: '+7 (347) 200-14-08',
      email: 'hello@lunny-dome.ru',
      signer: 'ИП Марина Р. Р.',
      accentHex: '#8B5CF6',
    ),
    const Company(
      id: 'c-sozvezdie',
      name: 'Планетарий «Созвездие»',
      shortName: 'Созвездие',
      city: 'Нижний Новгород',
      region: 'Нижегородская область',
      timezone: 'Europe/Moscow',
      inn: '526312345678',
      ogrnip: '321028000067890',
      legalAddress: '603000, г. Нижний Новгород, ул. Звёздная, 7, офис 2',
      bankDetails: 'АО «Волга-Банк» · р/с 40802810900000987654',
      phone: '+7 (831) 256-36-43',
      email: 'hello@sozvezdie-nn.ru',
      signer: 'ИП Марина Р. Р.',
      accentHex: '#22D3EE',
    ),
  ];

  const nnInstitutions = [
    Institution(
      id: 'i-nn-10',
      companyId: 'c-sozvezdie',
      type: InstitutionType.kindergarten,
      number: '10',
      name: 'Детский сад №10',
      city: 'Нижний Новгород',
      district: 'Нижегородский',
      address: 'ул. Октябрьская, д. 2',
      contactPerson: 'Светлана Юрьевна',
      position: 'Заведующая',
      phonePrimary: '8-831-256-36-43',
      phoneSecondary: '',
      email: 'sad10@nn.ru',
      website: '',
      groupsCount: 8,
      hallCapacity: 60,
      notes: 'Зал на втором этаже, нужен проектор.',
      lastVisitDate: null,
      totalVisits: 12,
      status: InstitutionStatus.verified,
      tags: ['постоянный', 'зал'],
      counterparty: CounterpartyType.legal,
      externalId: 'ext-nn-10',
    ),
    Institution(
      id: 'i-nn-15',
      companyId: 'c-sozvezdie',
      type: InstitutionType.school,
      number: '15',
      name: 'Школа №15',
      city: 'Нижний Новгород',
      district: 'Советский',
      address: 'ул. Горького, д. 40',
      contactPerson: 'Ирина Петровна',
      position: 'Заместитель директора',
      phonePrimary: '8-831-245-11-20',
      phoneSecondary: '',
      email: 'school15@nn.ru',
      website: '',
      groupsCount: 24,
      hallCapacity: 120,
      notes: 'Актовый зал, есть сцена.',
      lastVisitDate: null,
      totalVisits: 7,
      status: InstitutionStatus.active,
      tags: ['школа', 'актовый зал'],
      counterparty: CounterpartyType.legal,
      externalId: 'ext-nn-15',
    ),
    Institution(
      id: 'i-nn-45',
      companyId: 'c-sozvezdie',
      type: InstitutionType.kindergarten,
      number: '45',
      name: 'Детский сад №45 «Ромашка»',
      city: 'Дзержинск',
      district: 'Центральный',
      address: 'пр. Ленина, д. 18',
      contactPerson: 'Ольга Викторовна',
      position: 'Старший воспитатель',
      phonePrimary: '8-831-233-08-14',
      phoneSecondary: '',
      email: 'romashka45@nn.ru',
      website: '',
      groupsCount: 6,
      hallCapacity: 45,
      notes: '',
      lastVisitDate: null,
      totalVisits: 3,
      status: InstitutionStatus.active,
      tags: ['новый'],
      counterparty: CounterpartyType.legal,
      externalId: 'ext-nn-45',
    ),
    Institution(
      id: 'i-nn-g2',
      companyId: 'c-sozvezdie',
      type: InstitutionType.school,
      number: '2',
      name: 'Гимназия №2',
      city: 'Нижний Новгород',
      district: 'Канавинский',
      address: 'ул. Чкалова, д. 5',
      contactPerson: 'Александр Сергеевич',
      position: 'Директор',
      phonePrimary: '8-831-240-22-31',
      phoneSecondary: '',
      email: 'gym2@nn.ru',
      website: '',
      groupsCount: 30,
      hallCapacity: 150,
      notes: '',
      lastVisitDate: null,
      totalVisits: 5,
      status: InstitutionStatus.verified,
      tags: ['постоянный'],
      counterparty: CounterpartyType.legal,
      externalId: 'ext-nn-g2',
    ),
    Institution(
      id: 'i-nn-orbita',
      companyId: 'c-sozvezdie',
      type: InstitutionType.other,
      number: '',
      name: 'Центр развития «Орбита»',
      city: 'Нижний Новгород',
      district: 'Приокский',
      address: 'ул. Ларина, д. 9',
      contactPerson: 'Наталья Игоревна',
      position: 'Руководитель',
      phonePrimary: '8-831-219-77-03',
      phoneSecondary: '',
      email: 'orbita@nn.ru',
      website: '',
      groupsCount: 4,
      hallCapacity: 30,
      notes: 'Частный центр, оплата по счёту.',
      lastVisitDate: null,
      totalVisits: 2,
      status: InstitutionStatus.active,
      tags: ['частный'],
      counterparty: CounterpartyType.individual,
      externalId: 'ext-nn-orbita',
    ),
  ];

  const ufaInstitutions = [
    Institution(
      id: 'i-ufa-7',
      companyId: 'c-lunny',
      type: InstitutionType.kindergarten,
      number: '7',
      name: 'Детский сад №7 «Звёздочка»',
      city: 'Уфа',
      district: 'Кировский',
      address: 'ул. Космическая, д. 12',
      contactPerson: 'Гульнара Рашидовна',
      position: 'Заведующая',
      phonePrimary: '8-347-200-14-08',
      phoneSecondary: '',
      email: 'zvezda7@ufa.ru',
      website: '',
      groupsCount: 7,
      hallCapacity: 50,
      notes: '',
      lastVisitDate: null,
      totalVisits: 9,
      status: InstitutionStatus.verified,
      tags: ['постоянный'],
      counterparty: CounterpartyType.legal,
      externalId: 'ext-ufa-7',
    ),
    Institution(
      id: 'i-ufa-101',
      companyId: 'c-lunny',
      type: InstitutionType.school,
      number: '101',
      name: 'Школа №101',
      city: 'Уфа',
      district: 'Октябрьский',
      address: 'ул. Звёздная, д. 7',
      contactPerson: 'Ринат Фаритович',
      position: 'Завуч по воспитательной работе',
      phonePrimary: '8-347-233-51-90',
      phoneSecondary: '',
      email: 'school101@ufa.ru',
      website: '',
      groupsCount: 22,
      hallCapacity: 110,
      notes: '',
      lastVisitDate: null,
      totalVisits: 4,
      status: InstitutionStatus.active,
      tags: ['школа'],
      counterparty: CounterpartyType.legal,
      externalId: 'ext-ufa-101',
    ),
    Institution(
      id: 'i-ufa-23',
      companyId: 'c-lunny',
      type: InstitutionType.kindergarten,
      number: '23',
      name: 'Детский сад №23 «Лучик»',
      city: 'Уфа',
      district: 'Советский',
      address: 'ул. Лучевая, д. 3',
      contactPerson: 'Айгуль Маратовна',
      position: 'Старший воспитатель',
      phonePrimary: '8-347-241-06-72',
      phoneSecondary: '',
      email: 'luchik23@ufa.ru',
      website: '',
      groupsCount: 5,
      hallCapacity: 40,
      notes: '',
      lastVisitDate: null,
      totalVisits: 6,
      status: InstitutionStatus.active,
      tags: ['новый'],
      counterparty: CounterpartyType.legal,
      externalId: 'ext-ufa-23',
    ),
    Institution(
      id: 'i-ufa-lit5',
      companyId: 'c-lunny',
      type: InstitutionType.school,
      number: '5',
      name: 'Лицей №5',
      city: 'Уфа',
      district: 'Дёмский',
      address: 'ул. Планетарная, д. 21',
      contactPerson: 'Лилия Анваровна',
      position: 'Директор',
      phonePrimary: '8-347-228-44-15',
      phoneSecondary: '',
      email: 'licey5@ufa.ru',
      website: '',
      groupsCount: 28,
      hallCapacity: 140,
      notes: '',
      lastVisitDate: null,
      totalVisits: 8,
      status: InstitutionStatus.verified,
      tags: ['постоянный'],
      counterparty: CounterpartyType.legal,
      externalId: 'ext-ufa-lit5',
    ),
    Institution(
      id: 'i-ufa-mlechny',
      companyId: 'c-lunny',
      type: InstitutionType.other,
      number: '',
      name: 'Центр «Млечный путь»',
      city: 'Уфа',
      district: 'Калининский',
      address: 'ул. Гагарина, д. 14',
      contactPerson: 'Динара Ильдаровна',
      position: 'Администратор',
      phonePrimary: '8-347-210-33-88',
      phoneSecondary: '',
      email: 'mlechny@ufa.ru',
      website: '',
      groupsCount: 3,
      hallCapacity: 25,
      notes: '',
      lastVisitDate: null,
      totalVisits: 1,
      status: InstitutionStatus.active,
      tags: ['частный'],
      counterparty: CounterpartyType.individual,
      externalId: 'ext-ufa-mlechny',
    ),
  ];

  final programs = [
    const ProgramRecord(
      id: 'p-nn-1',
      companyId: 'c-sozvezdie',
      name: 'Путешествие по Солнечной системе',
      description: 'Знакомство с планетами, их размерами и орбитами.',
      audience: InstitutionType.kindergarten,
      ageGroup: '4–7 лет',
      durationMinutes: 40,
      isActive: true,
    ),
    const ProgramRecord(
      id: 'p-nn-2',
      companyId: 'c-sozvezdie',
      name: 'Космос вокруг нас',
      description: 'Звёзды, созвездия и профессия космонавта.',
      audience: InstitutionType.school,
      ageGroup: '1–5 класс',
      durationMinutes: 45,
      isActive: true,
    ),
    const ProgramRecord(
      id: 'p-nn-3',
      companyId: 'c-sozvezdie',
      name: 'Тайны Луны',
      description: 'Лунные фазы, приливы и история изучения Луны.',
      audience: InstitutionType.kindergarten,
      ageGroup: '5–7 лет',
      durationMinutes: 40,
      isActive: true,
    ),
    const ProgramRecord(
      id: 'p-nn-4',
      companyId: 'c-sozvezdie',
      name: 'Чёрные дыры',
      description: 'Гравитация, горизонт событий и современная астрофизика.',
      audience: InstitutionType.school,
      ageGroup: '8–11 класс',
      durationMinutes: 50,
      isActive: true,
    ),
    const ProgramRecord(
      id: 'p-ufa-1',
      companyId: 'c-lunny',
      name: 'Путешествие по Солнечной системе',
      description: 'Знакомство с планетами, их размерами и орбитами.',
      audience: InstitutionType.kindergarten,
      ageGroup: '4–7 лет',
      durationMinutes: 40,
      isActive: true,
    ),
    const ProgramRecord(
      id: 'p-ufa-2',
      companyId: 'c-lunny',
      name: 'Космос вокруг нас',
      description: 'Звёзды, созвездия и профессия космонавта.',
      audience: InstitutionType.school,
      ageGroup: '1–5 класс',
      durationMinutes: 45,
      isActive: true,
    ),
    const ProgramRecord(
      id: 'p-ufa-3',
      companyId: 'c-lunny',
      name: 'Тайны Луны',
      description: 'Лунные фазы, приливы и история изучения Луны.',
      audience: InstitutionType.kindergarten,
      ageGroup: '5–7 лет',
      durationMinutes: 40,
      isActive: true,
    ),
    const ProgramRecord(
      id: 'p-ufa-4',
      companyId: 'c-lunny',
      name: 'Чёрные дыры',
      description: 'Гравитация, горизонт событий и современная астрофизика.',
      audience: InstitutionType.school,
      ageGroup: '8–11 класс',
      durationMinutes: 50,
      isActive: true,
    ),
  ];

  final templates = [
    const TemplateRecord(
      id: 't-nn-k',
      companyId: 'c-sozvezdie',
      type: InstitutionType.kindergarten,
      name: 'Договор с детским садом',
      body: _templateBody,
    ),
    const TemplateRecord(
      id: 't-nn-s',
      companyId: 'c-sozvezdie',
      type: InstitutionType.school,
      name: 'Договор со школой',
      body: _templateBody,
    ),
    const TemplateRecord(
      id: 't-ufa-k',
      companyId: 'c-lunny',
      type: InstitutionType.kindergarten,
      name: 'Договор с детским садом',
      body: _templateBody,
    ),
    const TemplateRecord(
      id: 't-ufa-s',
      companyId: 'c-lunny',
      type: InstitutionType.school,
      name: 'Договор со школой',
      body: _templateBody,
    ),
  ];

  final events = <SeedEvent>[];
  var counter = 0;

  void addCompanyEvents(
    Company company,
    List<Institution> institutions,
    List<ProgramRecord> companyPrograms,
  ) {
    for (var monthOffset = 0; monthOffset < 6; monthOffset++) {
      for (final day in [8, 19]) {
        final date = DateTime(today.year, today.month - monthOffset, day);
        if (date.isAfter(today)) continue;
        final institution = institutions[(counter) % institutions.length];
        final program = companyPrograms[counter % companyPrograms.length];
        final children = 18 + ((counter * 7) % 23);
        events.add(
          SeedEvent(
            Event.draft(
              id: 'e-${company.id}-past-$counter',
              companyId: company.id,
              institution: institution,
              date: date,
              timeStart: counter.isEven ? '09:00' : '10:30',
              timezone: company.timezone,
              programName: program.name,
              childrenCount: children,
              pricePerChildKopecks: 25000,
              institutionPercentBp: 2500,
            ),
            EventStatus.completed,
          ),
        );
        counter++;
      }
    }

    final upcoming = [(1, '09:00'), (4, '10:30'), (9, '14:00')];
    for (var i = 0; i < upcoming.length; i++) {
      final (plusDays, time) = upcoming[i];
      final institution = institutions[(i + 2) % institutions.length];
      final program = companyPrograms[(i + 1) % companyPrograms.length];
      events.add(
        SeedEvent(
          Event.draft(
            id: 'e-${company.id}-next-$i',
            companyId: company.id,
            institution: institution,
            date: today.add(Duration(days: plusDays)),
            timeStart: time,
            timezone: company.timezone,
            programName: program.name,
            childrenCount: 22 + i * 6,
            pricePerChildKopecks: 25000,
            institutionPercentBp: 2500,
          ),
          EventStatus.scheduled,
        ),
      );
    }

    events.add(
      SeedEvent(
        Event.draft(
          id: 'e-${company.id}-cancelled',
          companyId: company.id,
          institution: institutions.first,
          date: today.subtract(const Duration(days: 3)),
          timeStart: '11:00',
          timezone: company.timezone,
          programName: companyPrograms.first.name,
          childrenCount: 20,
          pricePerChildKopecks: 25000,
          institutionPercentBp: 2500,
          notes: 'Отменено учреждением.',
        ),
        EventStatus.cancelled,
      ),
    );
  }

  addCompanyEvents(companies[1], nnInstitutions, programs.sublist(0, 4));
  addCompanyEvents(companies[0], ufaInstitutions, programs.sublist(4, 8));

  return SeedBundle(
    companies: companies,
    institutions: [...nnInstitutions, ...ufaInstitutions],
    programs: programs,
    templates: templates,
    events: events,
  );
}
