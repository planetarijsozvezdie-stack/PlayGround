export const COMPANIES = [
  {
    id: 'lunny',
    name: 'Лунный Дом',
    short: 'Лунный Дом',
    city: 'Уфа',
    region: 'Республика Башкортостан',
    accent: '#8b5cf6',
    accent2: '#c084fc',
    glyph: 'moon',
    legal: 'ИП Марина Р. Р.',
    inn: '027812345678',
    ogrnip: '321028000012345',
    address: '450000, г. Уфа, ул. Космическая, 12, офис 4',
    bank: 'ООО «Банк Урал» · р/с 40802810400000123456',
    phone: '+7 (347) 200-14-08',
    email: 'hello@lunny-dome.ru',
    signer: 'Марина Р. Р.'
  },
  {
    id: 'sozvezdie',
    name: 'Созвездие',
    short: 'Созвездие',
    city: 'Нижний Новгород',
    region: 'Нижегородская область',
    accent: '#22d3ee',
    accent2: '#818cf8',
    glyph: 'orbit',
    legal: 'ИП Марина Р. Р.',
    inn: '526312345678',
    ogrnip: '321028000067890',
    address: '603000, г. Нижний Новгород, ул. Звёздная, 7, офис 2',
    bank: 'АО «Волга-Банк» · р/с 40802810900000987654',
    phone: '+7 (831) 256-36-43',
    email: 'hello@sozvezdie-nn.ru',
    signer: 'Марина Р. Р.'
  }
];

export const TYPES = {
  kindergarten: { label: 'Детский сад', short: 'Сад', icon: 'blocks' },
  school: { label: 'Школа', short: 'Школа', icon: 'school' },
  other: { label: 'Прочее', short: 'Прочее', icon: 'spark' }
};

export const STATUSES = {
  active: { label: 'Активный', tone: 'neutral' },
  verified: { label: 'Проверено', tone: 'success' },
  inactive: { label: 'Неактивный', tone: 'muted' }
};

export const EVENT_STATUSES = {
  scheduled: { label: 'Запланировано', tone: 'accent' },
  completed: { label: 'Завершено', tone: 'success' },
  cancelled: { label: 'Отменено', tone: 'danger' }
};

export const MONTHS = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
export const MONTHS_NOM = ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];
export const WEEKDAYS = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
export const WEEKDAYS_FULL = ['Воскресенье', 'Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота'];

let counter = 0;
export function uid(prefix = 'id') {
  counter += 1;
  return `${prefix}-${Date.now().toString(36)}-${counter.toString(36)}`;
}

export function pad(n) {
  return String(n).padStart(2, '0');
}

export function iso(date) {
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

export function parseISO(value) {
  const [y, m, d] = String(value).split('-').map(Number);
  return new Date(y, (m || 1) - 1, d || 1);
}

export function addDays(date, days) {
  const next = new Date(date);
  next.setDate(next.getDate() + days);
  return next;
}

export function startOfWeek(date) {
  const next = new Date(date);
  const day = (next.getDay() + 6) % 7;
  next.setDate(next.getDate() - day);
  next.setHours(0, 0, 0, 0);
  return next;
}

function program(companyId, index, name, age, minutes, description) {
  return {
    id: `${companyId}-prog-${index}`,
    companyId,
    name,
    description,
    ageGroup: age,
    durationMinutes: minutes,
    fileName: `${name.replace(/\s+/g, '-').toLowerCase()}.pdf`,
    isActive: true,
    createdAt: '2026-02-12T10:00:00.000Z',
    updatedAt: '2026-09-18T10:00:00.000Z'
  };
}

function institution(companyId, index, data) {
  return {
    id: `${companyId}-inst-${index}`,
    companyId,
    type: data.type,
    number: data.number || '',
    name: data.name,
    city: data.city,
    district: data.district || '',
    address: data.address,
    contactPerson: data.contactPerson,
    position: data.position || 'Заведующая',
    phonePrimary: data.phonePrimary,
    phoneSecondary: data.phoneSecondary || '',
    email: data.email || '',
    website: data.website || '',
    groupsCount: data.groupsCount || 0,
    hallCapacity: data.hallCapacity || 0,
    ceilingHeight: data.ceilingHeight || 3,
    notes: data.notes || '',
    lastVisitDate: data.lastVisitDate || '',
    totalVisits: data.totalVisits || 0,
    status: data.status || 'active',
    tags: data.tags || [],
    createdAt: data.createdAt || '2026-03-01T09:00:00.000Z',
    updatedAt: '2026-10-12T09:00:00.000Z',
    syncedWithGoogle: false,
    googleSheetRowId: ''
  };
}

function makeEvents(companyId, institutions, programs, today) {
  const plan = [
    { offset: 1, time: '09:00', inst: 0, prog: 0, children: 26, price: 250, percent: 25, status: 'scheduled' },
    { offset: 1, time: '11:30', inst: 1, prog: 2, children: 32, price: 300, percent: 20, status: 'scheduled' },
    { offset: 2, time: '10:00', inst: 2, prog: 1, children: 24, price: 250, percent: 25, status: 'scheduled' },
    { offset: 4, time: '09:30', inst: 3, prog: 3, children: 38, price: 320, percent: 20, status: 'scheduled' },
    { offset: 7, time: '09:00', inst: 4, prog: 1, children: 22, price: 260, percent: 25, status: 'scheduled' },
    { offset: 9, time: '10:30', inst: 5, prog: 2, children: 29, price: 300, percent: 25, status: 'scheduled' },
    { offset: -1, time: '09:00', inst: 6, prog: 0, children: 28, price: 250, percent: 25, status: 'completed' },
    { offset: -3, time: '10:30', inst: 1, prog: 3, children: 35, price: 320, percent: 20, status: 'completed' },
    { offset: -6, time: '09:30', inst: 7, prog: 1, children: 21, price: 250, percent: 25, status: 'completed' },
    { offset: -9, time: '11:00', inst: 0, prog: 2, children: 27, price: 300, percent: 25, status: 'completed' },
    { offset: -4, time: '09:00', inst: 2, prog: 0, children: 24, price: 250, percent: 25, status: 'cancelled', notes: 'Перенесено по просьбе учреждения' },
    { offset: -14, time: '10:00', inst: 3, prog: 0, children: 30, price: 250, percent: 20, status: 'completed' },
    { offset: -21, time: '09:30', inst: 4, prog: 3, children: 33, price: 320, percent: 25, status: 'completed' }
  ];
  return plan.map((row, index) => {
    const date = iso(addDays(today, row.offset));
    const inst = institutions[row.inst];
    return {
      id: `${companyId}-ev-${index + 1}`,
      companyId,
      institutionId: inst.id,
      date,
      timeStart: row.time,
      durationMinutes: programs[row.prog].durationMinutes,
      programId: programs[row.prog].id,
      programName: programs[row.prog].name,
      childrenCount: row.children,
      pricePerChild: row.price,
      institutionPercent: row.percent,
      status: row.status,
      notes: row.notes || '',
      googleEventId: row.status === 'scheduled' ? `gcal_${companyId}_${index + 1}` : '',
      createdAt: '2026-10-01T08:00:00.000Z',
      updatedAt: '2026-10-12T08:00:00.000Z',
      completedAt: row.status === 'completed' ? `${date}T12:00:00.000Z` : ''
    };
  });
}

function template(companyId, type, name, extra) {
  const company = COMPANIES.find(c => c.id === companyId);
  return {
    id: `${companyId}-tpl-${type}`,
    companyId,
    type,
    name,
    templateContent: [
      `ДОГОВОР НА ОКАЗАНИЕ УСЛУГ № {{number}}`,
      ``,
      `г. ${company.city}`,
      `«{{date}}»`,
      ``,
      `Исполнитель: ${company.legal}, ИНН ${company.inn}, ОГРНИП ${company.ogrnip}, адрес: ${company.address}, в лице ${company.signer}, именуемый в дальнейшем «Исполнитель», с одной стороны, и`,
      ``,
      `Заказчик: {{institution}}, ИНН {{inn}}, адрес: {{address}}, в лице {{contact}}, именуемый в дальнейшем «Заказчик», с другой стороны, заключили настоящий договор о нижеследующем.`,
      ``,
      `1. ПРЕДМЕТ ДОГОВОРА`,
      `1.1. Исполнитель обязуется провести выездное мероприятие «{{program}}» для {{children}} детей по адресу: {{address}}.`,
      `1.2. Дата и время проведения: {{eventDate}} в {{eventTime}}.`,
      `1.3. Стоимость услуги: {{price}} ₽ за одного ребёнка.`,
      `1.4. Вознаграждение Заказчика: {{percent}}% от стоимости.`,
      ``,
      `2. ПОРЯДОК РАСЧЁТОВ`,
      `2.1. Общая стоимость услуг составляет {{total}} ₽.`,
      `2.2. Оплата производится в течение 5 рабочих дней после подписания акта.`,
      ``,
      `3. ПОДПИСИ СТОРОН`,
      `Исполнитель: ${company.signer} ____________________`,
      `Заказчик: {{contact}} ____________________`
    ].join('\n'),
    variables: ['number', 'date', 'institution', 'inn', 'address', 'contact', 'program', 'children', 'eventDate', 'eventTime', 'price', 'percent', 'total'],
    isActive: true,
    createdAt: '2026-01-20T10:00:00.000Z',
    updatedAt: '2026-09-01T10:00:00.000Z',
    ...extra
  };
}

function monthlyRevenue(companyId, today, base, fluctuation) {
  const rows = [];
  for (let i = 11; i >= 1; i -= 1) {
    const date = new Date(today.getFullYear(), today.getMonth() - i, 15);
    const seasonal = Math.round(Math.sin((date.getMonth() / 12) * Math.PI * 2) * fluctuation);
    rows.push({
      id: `seed-${companyId}-month-${i}`,
      companyId,
      eventId: null,
      date: iso(date),
      amount: base + seasonal + ((date.getMonth() * 7919) % 21000),
      category: 'session',
      taxRate: 4,
      comment: 'Сводная выручка за месяц',
      isAuto: false,
      createdAt: `${iso(date)}T18:00:00.000Z`,
      updatedAt: `${iso(date)}T18:00:00.000Z`,
      googleSheetRowId: ''
    });
  }
  return rows;
}

export function seedState() {
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const lunnyPrograms = [
    program('lunny', 1, 'Лунная одиссея', '3–7 лет', 40, 'Интерактивное путешествие к кратерам и морям Луны. Дети становятся экипажем лунной станции.'),
    program('lunny', 2, 'Тайны Солнечной системы', '1–4 класс', 45, 'Знакомство с планетами, их размерами и орбитами с полнокупольной визуализацией.'),
    program('lunny', 3, 'Чёрные дыры и время', '5–9 класс', 50, 'Гравитация, горизонт событий и путешествия во времени — научная программа для старшеклассников.'),
    program('lunny', 4, 'В поисках экзопланет', '10–11 класс', 45, 'Методы поиска далёких миров, зона обитаемости и современные телескопы.')
  ];
  const sozPrograms = [
    program('sozvezdie', 1, 'Космическое путешествие', '3–7 лет', 40, 'Первое знакомство с космосом: звёзды, планеты и отважные космонавты.'),
    program('sozvezdie', 2, 'Тайны Солнечной системы', '1–4 класс', 45, 'Полнокупольный рассказ о планетах, спутниках и астероидах.'),
    program('sozvezdie', 3, 'Чёрные дыры и время', '5–9 класс', 50, 'Что происходит за горизонтом событий и как гравитация искривляет время.'),
    program('sozvezdie', 4, 'Полярное сияние', '3–7 лет', 35, 'Магнитное поле Земли, солнечный ветер и северное сияние в формате сказки.')
  ];

  const lunnyInstitutions = [
    institution('lunny', 1, { type: 'kindergarten', number: '№ 251', name: 'Детский сад № 251', city: 'Уфа', district: 'Калининский', address: 'ул. Первомайская, 24', contactPerson: 'Гульнара Рашидовна', position: 'Заведующая', phonePrimary: '+7 (347) 262-31-45', email: 'ds251@ufa.ru', groupsCount: 12, hallCapacity: 60, ceilingHeight: 3.2, lastVisitDate: iso(addDays(today, -9)), totalVisits: 8, status: 'verified', tags: ['большой зал', 'постоянный'] }),
    institution('lunny', 2, { type: 'school', number: '№ 45', name: 'Школа № 45', city: 'Уфа', district: 'Октябрьский', address: 'ул. Менделеева, 3', contactPerson: 'Ирина Владимировна', position: 'Заместитель директора', phonePrimary: '+7 (347) 233-45-12', email: 'school45@ufa.ru', groupsCount: 24, hallCapacity: 120, ceilingHeight: 4.1, lastVisitDate: iso(addDays(today, -3)), totalVisits: 5, status: 'verified', tags: ['актовый зал'] }),
    institution('lunny', 3, { type: 'kindergarten', number: '№ 310', name: 'Детский сад № 310', city: 'Уфа', district: 'Калининский', address: 'ул. Ферина, 40', contactPerson: 'Зульфия Маратовна', position: 'Заведующая', phonePrimary: '+7 (347) 263-18-90', groupsCount: 10, hallCapacity: 55, ceilingHeight: 3, lastVisitDate: iso(addDays(today, -49)), totalVisits: 6, status: 'verified', tags: ['утренние сеансы'] }),
    institution('lunny', 4, { type: 'other', number: '', name: 'Центр развития «Умница»', city: 'Уфа', district: 'Кировский', address: 'ул. Цюрупы, 55', contactPerson: 'Эльмира Фаритовна', position: 'Директор', phonePrimary: '+7 (347) 251-77-03', groupsCount: 6, hallCapacity: 40, ceilingHeight: 3.4, lastVisitDate: iso(addDays(today, -21)), totalVisits: 4, status: 'active', tags: ['частный', 'центр развития'] }),
    institution('lunny', 5, { type: 'school', number: '№ 118', name: 'Школа № 118', city: 'Уфа', district: 'Орджоникидзевский', address: 'ул. Кольцевая, 8', contactPerson: 'Наталья Петровна', position: 'Завуч', phonePrimary: '+7 (347) 242-90-31', groupsCount: 28, hallCapacity: 140, ceilingHeight: 4.5, lastVisitDate: iso(addDays(today, -70)), totalVisits: 2, status: 'active', tags: [] }),
    institution('lunny', 6, { type: 'kindergarten', number: '№ 88', name: 'Детский сад «Солнышко»', city: 'Уфа', district: 'Советский', address: 'ул. Комсомольская, 12', contactPerson: 'Айгуль Ильдаровна', position: 'Старший воспитатель', phonePrimary: '+7 (347) 273-55-18', groupsCount: 9, hallCapacity: 50, ceilingHeight: 3.1, lastVisitDate: iso(addDays(today, -1)), totalVisits: 3, status: 'verified', tags: ['новый контакт'] }),
    institution('lunny', 7, { type: 'school', number: '№ 27', name: 'Школа № 27', city: 'Уфа', district: 'Дёмский', address: 'ул. Правды, 15', contactPerson: 'Светлана Юрьевна', position: 'Заместитель директора', phonePrimary: '+7 (347) 281-44-06', groupsCount: 22, hallCapacity: 110, ceilingHeight: 3.8, lastVisitDate: iso(addDays(today, -6)), totalVisits: 1, status: 'active', tags: [] }),
    institution('lunny', 8, { type: 'other', number: '', name: 'Лицей № 5', city: 'Уфа', district: 'Октябрьский', address: 'ул. Коммунистическая, 60', contactPerson: 'Ринат Ахметович', position: 'Директор', phonePrimary: '+7 (347) 223-15-71', groupsCount: 18, hallCapacity: 90, ceilingHeight: 3.9, totalVisits: 0, status: 'active', tags: ['потенциальный'] })
  ];

  const sozInstitutions = [
    institution('sozvezdie', 1, { type: 'kindergarten', number: '№ 10', name: 'Детский сад № 10', city: 'Нижний Новгород', district: 'Нижегородский', address: 'ул. Октябрьская, 2', contactPerson: 'Светлана Юрьевна', position: 'Заведующая', phonePrimary: '8-831-256-36-43', email: 'ds10@nn.ru', groupsCount: 11, hallCapacity: 60, ceilingHeight: 3.2, lastVisitDate: iso(addDays(today, -9)), totalVisits: 9, status: 'verified', tags: ['большой зал', 'постоянный'] }),
    institution('sozvezdie', 2, { type: 'school', number: '№ 15', name: 'Школа № 15', city: 'Нижний Новгород', district: 'Советский', address: 'ул. Кузнечихинская, 100', contactPerson: 'Елена Андреевна', position: 'Заместитель директора', phonePrimary: '+7 (831) 465-22-18', groupsCount: 26, hallCapacity: 130, ceilingHeight: 4.2, lastVisitDate: iso(addDays(today, -3)), totalVisits: 7, status: 'verified', tags: ['актовый зал'] }),
    institution('sozvezdie', 3, { type: 'kindergarten', number: '№ 45', name: 'Детский сад «Ручеёк»', city: 'Нижний Новгород', district: 'Автозаводский', address: 'пр. Молодёжный, 12', contactPerson: 'Ольга Николаевна', position: 'Заведующая', phonePrimary: '+7 (831) 293-41-07', groupsCount: 8, hallCapacity: 45, ceilingHeight: 3, lastVisitDate: iso(addDays(today, -35)), totalVisits: 4, status: 'active', tags: ['утренние сеансы'] }),
    institution('sozvezdie', 4, { type: 'school', number: '№ 53', name: 'Гимназия № 53', city: 'Нижний Новгород', district: 'Приокский', address: 'ул. Васюнина, 4', contactPerson: 'Марина Александровна', position: 'Директор', phonePrimary: '+7 (831) 467-80-12', groupsCount: 30, hallCapacity: 160, ceilingHeight: 4.6, lastVisitDate: iso(addDays(today, -50)), totalVisits: 3, status: 'verified', tags: ['премиум'] }),
    institution('sozvezdie', 5, { type: 'other', number: '', name: 'Центр «Планета детства»', city: 'Нижний Новгород', district: 'Канавинский', address: 'ул. Гороховецкая, 8', contactPerson: 'Татьяна Игоревна', position: 'Директор', phonePrimary: '+7 (831) 246-33-90', groupsCount: 5, hallCapacity: 35, ceilingHeight: 3.3, lastVisitDate: iso(addDays(today, -21)), totalVisits: 2, status: 'active', tags: ['частный'] }),
    institution('sozvezdie', 6, { type: 'school', number: '№ 121', name: 'Школа № 121', city: 'Нижний Новгород', district: 'Сормовский', address: 'ул. Планетная, 4', contactPerson: 'Алексей Викторович', position: 'Завуч', phonePrimary: '+7 (831) 225-61-84', groupsCount: 24, hallCapacity: 115, ceilingHeight: 4, lastVisitDate: iso(addDays(today, -80)), totalVisits: 1, status: 'inactive', tags: [] }),
    institution('sozvezdie', 7, { type: 'kindergarten', number: '№ 88', name: 'Детский сад № 88', city: 'Дзержинск', district: '', address: 'ул. Маяковского, 20', contactPerson: 'Надежда Васильевна', position: 'Заведующая', phonePrimary: '+7 (8313) 26-14-55', groupsCount: 10, hallCapacity: 55, ceilingHeight: 3.1, lastVisitDate: iso(addDays(today, -6)), totalVisits: 2, status: 'active', tags: ['область'] }),
    institution('sozvezdie', 8, { type: 'school', number: '№ 3', name: 'Школа № 3', city: 'Дзержинск', district: '', address: 'ул. Свердлова, 18', contactPerson: 'Игорь Борисович', position: 'Директор', phonePrimary: '+7 (8313) 22-08-71', groupsCount: 20, hallCapacity: 100, ceilingHeight: 3.7, totalVisits: 0, status: 'active', tags: ['потенциальный', 'область'] })
  ];

  const lunnyEvents = makeEvents('lunny', lunnyInstitutions, lunnyPrograms, today);
  const sozEvents = makeEvents('sozvezdie', sozInstitutions, sozPrograms, today);

  const revenues = [
    ...monthlyRevenue('lunny', today, 172000, 24000),
    ...monthlyRevenue('sozvezdie', today, 205000, 31000)
  ];

  [...lunnyEvents, ...sozEvents].filter(e => e.status === 'completed').forEach(event => {
    const inst = [...lunnyInstitutions, ...sozInstitutions].find(i => i.id === event.institutionId);
    const total = event.childrenCount * event.pricePerChild;
    revenues.push({
      id: `seed-rev-${event.id}`,
      companyId: event.companyId,
      eventId: event.id,
      date: event.date,
      amount: total,
      category: 'session',
      taxRate: inst?.type === 'school' ? 6 : 4,
      comment: `Сеанс · ${inst?.name || 'Мероприятие'}`,
      isAuto: true,
      createdAt: `${event.date}T14:00:00.000Z`,
      updatedAt: `${event.date}T14:00:00.000Z`,
      googleSheetRowId: ''
    });
  });

  revenues.push(
    { id: 'seed-rev-lunny-extra-1', companyId: 'lunny', eventId: null, date: iso(addDays(today, -2)), amount: 8400, category: 'other', taxRate: 4, comment: 'Индивидуальный сеанс для семьи', isAuto: false, createdAt: '', updatedAt: '', googleSheetRowId: '' },
    { id: 'seed-rev-lunny-extra-2', companyId: 'lunny', eventId: null, date: iso(addDays(today, -8)), amount: 4500, category: 'other', taxRate: 4, comment: 'Сувенирная продукция', isAuto: false, createdAt: '', updatedAt: '', googleSheetRowId: '' },
    { id: 'seed-rev-soz-extra-1', companyId: 'sozvezdie', eventId: null, date: iso(addDays(today, -5)), amount: 12000, category: 'other', taxRate: 6, comment: 'Корпоративное мероприятие', isAuto: false, createdAt: '', updatedAt: '', googleSheetRowId: '' }
  );

  const completed = [...lunnyEvents, ...sozEvents].filter(e => e.status === 'completed').slice(0, 6);
  const documents = [];
  completed.forEach((event, index) => {
    const inst = [...lunnyInstitutions, ...sozInstitutions].find(i => i.id === event.institutionId);
    const type = index % 3 === 2 ? 'act' : 'contract';
    documents.push({
      id: `seed-doc-${index + 1}`,
      companyId: event.companyId,
      eventId: event.id,
      type,
      title: `${type === 'contract' ? 'Договор' : 'Акт'} · ${inst?.name || 'Мероприятие'}`,
      filePath: `/Документы/${event.companyId}/${event.date}.pdf`,
      googleDriveFileId: `drive_${index + 1}`,
      createdAt: `${event.date}T15:00:00.000Z`,
      signed: true,
      signedDate: event.date
    });
  });

  return {
    version: 1,
    company: null,
    theme: 'dark',
    institutions: [...lunnyInstitutions, ...sozInstitutions],
    events: [...lunnyEvents, ...sozEvents],
    programs: [...lunnyPrograms, ...sozPrograms],
    templates: [
      template('sozvezdie', 'kindergarten', 'Созвездие · детский сад'),
      template('sozvezdie', 'school', 'Созвездие · школа'),
      template('lunny', 'kindergarten', 'Лунный Дом · детский сад'),
      template('lunny', 'school', 'Лунный Дом · школа')
    ],
    documents,
    revenues,
    reminders: [
      { id: 'rem-1', companyId: 'sozvezdie', eventId: sozEvents[0].id, title: 'Подготовить договор для сада № 10', reminderDate: `${iso(addDays(today, 0))}T18:00:00`, isCompleted: false, repeatInterval: 'none' },
      { id: 'rem-2', companyId: 'lunny', eventId: null, title: 'Позвонить в школу № 118', reminderDate: `${iso(addDays(today, 2))}T11:00:00`, isCompleted: false, repeatInterval: 'none' }
    ],
    settings: {
      googleCalendar: true,
      googleDrive: true,
      googleSheets: false,
      calendarName: 'Планетарий',
      reminderDay: true,
      reminderHour: true,
      colorId: '9',
      aiProvider: 'gigachat',
      aiKey: '',
      calcMode: 'gross',
      autoRevenue: true,
      biometrics: false,
      pin: '',
      syncFrequency: '5min'
    },
    chat: []
  };
}
