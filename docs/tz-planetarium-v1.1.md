# ТЗ «Планетарий Менеджер» — версия 1.1

**Дата:** 21.10.2026
**База:** ТЗ v1.0
**Статус:** рабочая версия для разработки. Все спорные места v1.0 закрыты решением, а не вопросом; бизнес-вопросы, требующие ответа Марины, вынесены в раздел 11.

---

## 0. Что изменено относительно v1.0

| № | Было (v1.0) | Стало (v1.1) | Причина |
|---|---|---|---|
| 1 | Часовой пояс не хранился, в Google Calendar захардкожен `Europe/Moscow` | У компании и мероприятия есть IANA-таймзона; Уфа — `Asia/Yekaterinburg` (UTC+5), НН — `Europe/Moscow` (UTC+3) | Иначе события Уфы уезжают на 2 часа |
| 2 | Firebase «опционально», но есть роли, push и «кто изменил» | v1 — одно устройство, без backend, без ролей, без push. Мультиустройство — v2 | Без сервера перечисленное не работает |
| 3 | PIN «шифруется» | PIN хешируется Argon2id, БД шифруется SQLCipher | Шифрование PIN обратимо, хеш — нет |
| 4 | `INTEGER PRIMARY KEY` | UUID v4 (TEXT) во всех синхронизируемых таблицах | Автоинкремент ломается при слиянии устройств и Sheets |
| 5 | Деньги `REAL` | Деньги в копейках, `INTEGER`; проценты в базисных пунктах | Округление рублей даёт расхождения в отчётах |
| 6 | Авто- и ручная выручка без правил | Одна авто-запись на мероприятие (`UNIQUE`), сторно при отмене, обязательный `event_id` у авто-записи | Убирает двойной учёт |
| 7 | Налог 4% / 6% по категории | 4% — физлицо, 6% — юрлицо; учтён вычет 10 000 ₽; период — месяц | Сады и школы — юрлица; НПД платится ежемесячно |
| 8 | 5 вкладок + ИИ в нижней панели | 5 вкладок, ИИ — FAB на «Главной» (v2) | 6 вкладок не помещаются |
| 9 | Свайп влево удалить, свайп вправо завершить | Свайп влево — удалить с undo; «Завершить» — из меню карточки | Свайп конфликтует с листанием календаря |
| 10 | Нет soft delete и очереди синхронизации | `deleted_at`, `version`, таблица `outbox` | Оффлайн и синхронизация без этого невозможны |
| 11 | Мероприятие ссылается на учреждение | Плюс `institution_snapshot` (JSON) | Переименование сада не должно менять старые договоры |
| 12 | Нет таблиц под CRM и рассылки | Добавлены `interactions`, `tasks`, `mailings`, `mailing_recipients`, `attachments` | Модули 2.9.1–2.9.2 были без схемы |
| 13 | Нет реквизитов компании | `inn`, `ogrnip`, `legal_address`, `bank_details`, `signer` | Договор нечего подставлять |
| 14 | Google realtime / push | Синхронизация при старте, вручную и WorkManager (≥15 мин); уведомления локальные | Ограничения Android Doze и отсутствие сервера |
| 15 | Sheets two-way realtime | v1.1: экспорт; импорт — вручную с предпросмотром и диффом | Silent two-way без сервера теряет данные |
| 16 | minSdk 24 | minSdk 26, target 35 | Google Sign-In, exact alarms, PDF-стек |
| 17 | ИИ с ФИО/телефонами в OpenAI | Только GigaChat/Yandex по умолчанию, слой редактирования ПДн | 152-ФЗ, трансграничная передача |
| 18 | «Чеки НПД» подразумевались | Приложение считает налог, но чеки не формирует | У «Мой налог» нет публичного API |
| 19 | Excel/CSV/Sheets «распознавание полей» | Обязательный экран сопоставления колонок + предпросмотр | Автоугадывание ошибается на реальных файлах |
| 20 | Веб-прототип не упомянут | `src/` считается визуальным референсом, не продакшн-кодом; токены берутся из `src/styles.css` | Уже есть согласованный вид |

---

## 1. Границы этапов

Приоритеты: **P0** — без этого продукт не работает, **P1** — обещано, но можно после запуска, **P2** — развитие.

### v1.0 (P0)

- Выбор компании, сохранение выбора, смена компании.
- Главная: приветствие, ближайшее мероприятие, статистика месяца, быстрые действия.
- Расписание: вкладки «Запланированные / Завершённые / Отменённые», виды «День» и «Неделя», CRUD, фильтры, поиск.
- База учреждений: CRUD, поиск, фильтры, сортировка, импорт/экспорт XLSX и CSV, массовые операции, история изменений.
- Выручка: ручной ввод, авто-начисление при завершении, сторно, дашборд, оценка НПД, экспорт XLSX/CSV и PDF-отчёт с таблицей месяцев и операций.
- Документы: программы, 4 шаблона договоров, генерация договора/акта/счёта в PDF, локальный архив с поиском, сортировкой, отметкой «подписан», мягким удалением и открытием в системном просмотрщике (Android) или новой вкладке браузера (веб).
- Локальные уведомления, PIN + биометрия, шифрование БД, локальный бэкап-файл.

### v1.1 (P1)

- Google Calendar: OAuth, односторонняя запись + импорт изменений по кнопке и при старте, напоминания.
- Google Drive: документы и бэкап в `/Планетарий/[Компания]/`.
- Google Sheets: экспорт базы и финансов; импорт с предпросмотром.
- Вид «Месяц», архив подписанных документов с поиском.
- Рассылки: шаблоны и отправка через внешний почтовый клиент (`mailto:`/share), без серверной отправки.

### v2 (P2)

- ИИ-ассистент (GigaChat / Yandex GPT), чат, голосовой ввод, история.
- CRM-воронка, напоминания о follow-up, аналитика и карта.
- Мультиустройство, роли (администратор / менеджер / просмотр), backend.
- iOS.

---

## 2. Домен

### 2.1 Время

- Компания хранит `timezone` (IANA): `Лунный Дом` → `Asia/Yekaterinburg`, `Созвездие` → `Europe/Moscow`.
- Мероприятие хранит локальные `event_date` (`YYYY-MM-DD`) и `time_start` (`HH:MM`) **и** снапшот `timezone` на момент создания.
- Все служебные даты (`created_at`, `updated_at`, `deleted_at`, `last_synced_at`) — UTC ISO-8601.
- Google Calendar получает `dateTime` со смещением и `timeZone` из снапшота мероприятия.
- Границы «сегодня», «месяц», «год» в отчётах считаются в таймзоне компании, а не устройства.
- Перелёт/смена таймзоны компании не пересчитывает старые мероприятия.

### 2.2 Деньги

Хранение — копейки (`INTEGER`), проценты — базисные пункты (`2500` = 25,00%). Округление — half-up до копейки на каждом шаге.

```
gross      = children_count × price_per_child
share      = round(gross × institution_percent_bp / 10000)
net        = gross − share
tax_base   = net        (по умолчанию, настройка tax_base = received | gross)
tax_amount = round(tax_base × tax_rate_bp / 10000) − deduction_applied
```

- `tax_base = received` — исполнитель получает сумму за вычетом доли учреждения (по умолчанию).
- `tax_base = gross` — доступно в настройках компании, если договор заключается на полную сумму.
- Выбор базы подтверждается бухгалтером (см. раздел 11, п. 2).
- При изменении `children_count` или `price_per_child` у завершённого мероприятия авто-запись пересчитывается; если она уже выгружена в Sheets — создаётся корректирующая запись, а не правка старой.

**Пример:** 25 детей × 250 ₽ = 6 250,00 ₽; доля сада 25% = 1 562,50 ₽; к получению 4 687,50 ₽; налог 6% = 281,25 ₽, вычет 2% = 93,75 ₽, к уплате 187,50 ₽ (эффективно 4%).

### 2.3 Налог на профессиональный доход

- Ставка: `4%` — заказчик физлицо, `6%` — юрлицо/ИП. Учреждения по умолчанию `legal`.
- Вычет: 10 000 ₽ за всё время. Пока вычет не исчерпан, налог уменьшается на 1% (при 4%) или 2% (при 6%) от базы. Хранится в `tax_state`.
- Налоговый период — **месяц**. Квартал и год — только агрегаты для отчётов, не «сумма к уплате за квартал».
- Чеки формируются вручную в «Мой налог»; приложение показывает сумму и период, но не подаёт данные в ФНС.
- Отчёт «Налог за период» содержит: база, ставка, вычет, начислено, разбивка по контрагентам.

### 2.4 Статусы мероприятия и выручка

```
scheduled ──complete──▶ completed ──reopen──▶ scheduled
    │                       │
    └────cancel─────────────┴──▶ cancelled
```

| Переход | Действие с выручкой |
|---|---|
| `scheduled → completed` | `revenue_mode = auto`: создать авто-запись. `confirm`: создать задачу «Подтвердить выручку» |
| `completed → scheduled` | Авто-запись помечается `deleted_at` + `is_reversed = 1`, создаётся отрицательная строка сторно |
| `* → cancelled` | То же сторно, если авто-запись существует |
| Редактирование суммы у завершённого | Пересчёт или корректирующая строка (см. 2.2) |
| Ручная запись с `event_id` | Авто-запись для этого события не создаётся (уникальный индекс + проверка) |

Сторно никогда не удаляет историю физически: отчётность должна воспроизводиться на любую дату.

---

## 3. Экраны

### 3.1 Старт и выбор компании

- Первый запуск или «Сброс настроек» → экран с двумя карточками компаний.
- Выбор пишется в `app_settings.selected_company_id`; повторный запуск сразу открывает «Главную».
- Смена компании — в профиле; данные не смешиваются, каждый запрос фильтруется по `company_id`.
- Перед сменой компании несохранённые формы закрываются с подтверждением.

### 3.2 Навигация

Нижняя панель: **Главная · Расписание · База · Документы · Выручка**.
Верхняя панель: название компании, кнопка профиля. В профиле: имя, PIN, биометрия, тема, интеграции, смена компании, экспорт/импорт, «О приложении».
ИИ-помощник — FAB на «Главной» (v2), не в нижней панели.

### 3.3 Главная

- Приветствие по имени из профиля.
- Ближайшее мероприятие: дата, время, учреждение, адрес; тап → «Расписание» на этой дате.
- Статистика месяца: завершённые сеансы, выручка (net), запланированные мероприятия.
- Быстрые действия: «Добавить мероприятие», «Добавить учреждение», «Создать документ».
- Плашка «Нет соединения» / «Есть неотправленные изменения» при наличии очереди.

### 3.4 Расписание

- Вкладки: «Запланированные», «Завершённые», «Отменённые».
- Виды: «День» (v1.0), «Неделя» (v1.0), «Месяц» (v1.1).
- Карточка: дата/время, тип и название учреждения, адрес, контакт и телефон, цена, доля учреждения, число детей, программа, статус.
- Действия: FAB «+», тап — редактирование, свайп влево — удаление с undo (5 секунд), меню карточки — «Завершить», «Отменить», «Создать договор», «Скопировать».
- Завершение мероприятия с будущей датой разрешено, но требует подтверждения.
- Фильтры: диапазон дат, город, тип учреждения, программа, статус. Поиск — по названию учреждения и адресу.
- Форма: дата, время, длительность (40 мин по умолчанию), поиск учреждения из базы, либо ручное заполнение; программа; дети; цена (250 ₽); доля (25%); примечания.
- При выборе учреждения из базы поля адреса и контактов заполняются, но остаются редактируемыми и сохраняются в снапшот.

### 3.5 База

- Категории: детские сады, школы, прочие. Разделение по `company_id`.
- Карточка: все поля из v1.0 + `counterparty_type` (юрлицо/физлицо) + теги.
- Список: карточки и таблица. Сортировка: название, город, последний визит, число сеансов.
- Поиск: название, номер, город, адрес, контакт, телефон (LIKE по нормализованной строке; 10 000 записей — допустимо).
- Фильтры: тип, город, район, статус, теги.
- Действия: добавить, редактировать, удалить (soft delete + undo), дублировать, «Проверено», массовые операции.
- Импорт: XLSX/CSV → экран сопоставления колонок → предпросмотр → импорт с логом ошибок. Дубликаты определяются по `company_id + type + number + city`; пользователь выбирает «пропустить / обновить / создать».
- Экспорт: XLSX/CSV с текущими фильтрами.
- История изменений — из `change_log`, с фильтром по учреждению.

### 3.6 Документы

- Разделы: «Программы», «Шаблоны договоров», «Документы» (архив), «Счета и акты».
- Программы: PDF, название, описание, возраст/класс, длительность, активность. Для садов и школ раздельно.
- Шаблоны: 4 штуки (компания × тип учреждения). Переменные вида `{{institution_name}}`. Редактор — plain text + предпросмотр; шрифты с кириллицей встраиваются в PDF (PT Sans / DejaVu Sans).
- Генерация: из мероприятия → выбор шаблона → предпросмотр → PDF → сохранение в архив → (v1.1) загрузка в Drive.
- Нумерация: `ПЛ-{КОД}-{ТИП}-{ГОД}-{NNNN}`, счётчики в `doc_counters`.
- Акт создаётся после завершения; счёт — по кнопке. Договор можно создать до мероприятия.
- Архив: поиск по названию/номеру/дате, сортировка, просмотр PDF, удаление (soft delete), отметка «подписан».
- Структура папок Drive: `/Планетарий/{Компания}/{Договоры|Акты|Счета}/{Год}/{Месяц}/`.

### 3.7 Выручка

- Плашки: сегодня, месяц, год, сравнение с прошлым месяцем и годом.
- Графики: столбцы по месяцам, линия за 30 дней, круг по компаниям (на уровне приложения — только выбранная компания + сводка «все компании»).
- Ручной ввод: дата, сумма, компания, категория, контрагент (юрлицо/физлицо), комментарий.
- Автоначисление: см. 2.4. Настройка `revenue_mode = auto | confirm`.
- Налог: плашка «НПД за месяц», разбивка по ставкам, остаток вычета.
- Экспорт: XLSX, CSV, PDF-отчёт с графиками за период.
- Все суммы в отчётах — без НДС (НПД не является НДС), с пометкой «оценка».

### 3.8 Профиль и настройки

- Имя, PIN (4–6 цифр), биометрия, тема (тёмная/светлая/системная).
- Компания, таймзона (только чтение), реквизиты (только чтение в v1.0).
- Интеграции: Google Calendar / Drive / Sheets, статус подключения, «Отключить».
- Выручка: режим авто/подтверждение, налоговая база (`received`/`gross`).
- Напоминания: за 1 день, за 1 час (вкл/выкл).
- Данные: экспорт, импорт, бэкап, очистка, сброс.
- Диагностика: версия, размер БД, очередь синхронизации, последняя синхронизация.

---

## 4. Интеграции

### 4.1 Google Calendar

- OAuth 2.0, scope `https://www.googleapis.com/auth/calendar`, токены в `flutter_secure_storage`.
- Создание/обновление/удаление события при соответствующих операциях с мероприятием.
- Событие: summary `Планетарий: {учреждение}`, описание с контактом, детьми, программой; `start/end` с таймзоной компании; `colorId = 9`.
- Напоминания: если синхронизация включена, напоминания живут в Google Calendar, локальные дубли отключены; если выключена — только локальные.
- Импорт изменений: при старте приложения, по кнопке и WorkManager (минимум 15 минут). Не «realtime».
- Конфликт: сравниваются `updated` события и `remote_updated_at`. Если менялись обе стороны — побеждает локальная версия, конфликт пишется в лог и показывается в диагностике.
- Удалённое событие в Google: мероприятие не удаляется, а помечается «конфликт: событие удалено в календаре» и требует решения пользователя.

### 4.2 Google Drive

- Scope `https://www.googleapis.com/auth/drive.file`; выбор корневой папки через Google Picker (файлы, созданные приложением).
- Загрузка PDF и бэкапов БД; повтор при появлении сети через `outbox`.
- Бэкап: ежедневно/еженедельно, хранить последние 7 копий, имя `backup-{company}-{yyyyMMdd-HHmm}.zip`.
- Восстановление — только явной командой «Восстановить из бэкапа» с предпросмотром даты и размера.

### 4.3 Google Sheets

- Scope `https://www.googleapis.com/auth/spreadsheets`.
- Синхронизация по стабильной колонке `ID` (UUID), а не по номеру строки.
- v1.1: экспорт базы и финансов, обновление существующей таблицы батчами.
- Импорт — вручную: чтение → предпросмотр → дифф → применение. Молчаливая двусторонняя синхронизация запрещена.
- Экспорт финансов помечает строки как выгруженные (`google_sheet_row`), чтобы корректировки создавались отдельными строками.

### 4.4 ИИ (v2)

- Провайдеры: GigaChat, Yandex GPT (данные в РФ), OpenAI — только с явным предупреждением о трансграничной передаче.
- Из запроса вырезаются ФИО, телефоны, email, адреса; в модель уходят агрегаты и ID.
- Чат-история хранится локально, отправляется только по кнопке.
- Голосовой ввод — через системный распознаватель, без отправки аудио в AI-провайдера.

### 4.5 Уведомления

- Только локальные (`flutter_local_notifications`): за 1 день и за 1 час, плюс задачи из `tasks`.
- Разрешения: `POST_NOTIFICATIONS` (Android 13+), `SCHEDULE_EXACT_ALARM` с деградацией до неточных напоминаний, если пользователь запретил.
- Push (FCM) не используется до появления backend.

---

## 5. Модель данных

SQLite + SQLCipher. Все ID — UUID v4 (`TEXT`). Все таблицы, участвующие в синхронизации, имеют `created_at`, `updated_at`, `deleted_at`, `version`.

```sql
PRAGMA foreign_keys = ON;

CREATE TABLE companies (
  id            TEXT PRIMARY KEY,
  name          TEXT NOT NULL,
  short_name    TEXT NOT NULL,
  city          TEXT NOT NULL,
  region        TEXT,
  timezone      TEXT NOT NULL,
  inn           TEXT,
  ogrnip        TEXT,
  legal_address TEXT,
  bank_details  TEXT,
  phone         TEXT,
  email         TEXT,
  signer        TEXT,
  logo_path     TEXT,
  accent        TEXT,
  sort_order    INTEGER NOT NULL DEFAULT 0,
  is_active     INTEGER NOT NULL DEFAULT 1,
  created_at    TEXT NOT NULL,
  updated_at    TEXT NOT NULL,
  deleted_at    TEXT
);

CREATE TABLE users (
  id                TEXT PRIMARY KEY,
  name              TEXT NOT NULL,
  email             TEXT,
  phone             TEXT,
  pin_hash          TEXT,
  pin_salt          TEXT,
  biometric_enabled INTEGER NOT NULL DEFAULT 0,
  created_at        TEXT NOT NULL,
  updated_at        TEXT NOT NULL,
  deleted_at        TEXT
);

CREATE TABLE institutions (
  id                 TEXT PRIMARY KEY,
  company_id         TEXT NOT NULL REFERENCES companies(id),
  type               TEXT NOT NULL CHECK (type IN ('kindergarten','school','other')),
  number             TEXT,
  name               TEXT NOT NULL,
  city               TEXT NOT NULL,
  district           TEXT,
  address            TEXT,
  contact_person     TEXT,
  position           TEXT,
  phone_primary      TEXT,
  phone_secondary    TEXT,
  email              TEXT,
  website            TEXT,
  groups_count       INTEGER,
  hall_capacity      INTEGER,
  ceiling_height_cm  INTEGER,
  counterparty_type  TEXT NOT NULL DEFAULT 'legal' CHECK (counterparty_type IN ('legal','individual')),
  notes              TEXT,
  last_visit_date    TEXT,
  total_visits       INTEGER NOT NULL DEFAULT 0,
  status             TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive','verified')),
  tags               TEXT NOT NULL DEFAULT '[]',
  external_id        TEXT NOT NULL,
  created_at         TEXT NOT NULL,
  updated_at         TEXT NOT NULL,
  version            INTEGER NOT NULL DEFAULT 1,
  deleted_at         TEXT
);

CREATE UNIQUE INDEX ux_institutions_natural
  ON institutions(company_id, type, number, city)
  WHERE deleted_at IS NULL AND number IS NOT NULL;

CREATE INDEX ix_institutions_company ON institutions(company_id, deleted_at);
CREATE INDEX ix_institutions_city ON institutions(company_id, city, type);

CREATE TABLE programs (
  id               TEXT PRIMARY KEY,
  company_id       TEXT NOT NULL REFERENCES companies(id),
  name             TEXT NOT NULL,
  description      TEXT,
  audience         TEXT NOT NULL CHECK (audience IN ('kindergarten','school')),
  age_group        TEXT,
  duration_minutes INTEGER NOT NULL DEFAULT 40,
  file_path        TEXT,
  file_checksum    TEXT,
  is_active        INTEGER NOT NULL DEFAULT 1,
  created_at       TEXT NOT NULL,
  updated_at       TEXT NOT NULL,
  version          INTEGER NOT NULL DEFAULT 1,
  deleted_at       TEXT
);

CREATE TABLE contract_templates (
  id               TEXT PRIMARY KEY,
  company_id       TEXT NOT NULL REFERENCES companies(id),
  type             TEXT NOT NULL CHECK (type IN ('kindergarten','school')),
  name             TEXT NOT NULL,
  template_content TEXT NOT NULL,
  variables        TEXT NOT NULL DEFAULT '[]',
  file_path        TEXT,
  is_active        INTEGER NOT NULL DEFAULT 1,
  created_at       TEXT NOT NULL,
  updated_at       TEXT NOT NULL,
  version          INTEGER NOT NULL DEFAULT 1,
  deleted_at       TEXT
);

CREATE TABLE events (
  id                        TEXT PRIMARY KEY,
  company_id                TEXT NOT NULL REFERENCES companies(id),
  institution_id            TEXT REFERENCES institutions(id),
  institution_snapshot      TEXT NOT NULL,
  event_date                TEXT NOT NULL,
  time_start                TEXT NOT NULL,
  duration_minutes          INTEGER NOT NULL DEFAULT 40 CHECK (duration_minutes BETWEEN 10 AND 480),
  timezone                  TEXT NOT NULL,
  program_id                TEXT REFERENCES programs(id),
  program_name              TEXT NOT NULL,
  children_count            INTEGER NOT NULL CHECK (children_count >= 0),
  price_per_child_kopecks   INTEGER NOT NULL CHECK (price_per_child_kopecks >= 0),
  institution_percent_bp    INTEGER NOT NULL DEFAULT 2500 CHECK (institution_percent_bp BETWEEN 0 AND 10000),
  gross_kopecks             INTEGER NOT NULL,
  institution_share_kopecks INTEGER NOT NULL,
  net_kopecks               INTEGER NOT NULL,
  status                    TEXT NOT NULL DEFAULT 'scheduled'
                            CHECK (status IN ('scheduled','completed','cancelled')),
  notes                     TEXT,
  google_event_id           TEXT,
  google_calendar_id        TEXT,
  last_synced_at            TEXT,
  remote_updated_at         TEXT,
  completed_at              TEXT,
  cancelled_at              TEXT,
  created_at                TEXT NOT NULL,
  updated_at                TEXT NOT NULL,
  version                   INTEGER NOT NULL DEFAULT 1,
  deleted_at                TEXT
);

CREATE INDEX ix_events_calendar ON events(company_id, event_date, time_start);
CREATE INDEX ix_events_status ON events(company_id, status, event_date);
CREATE UNIQUE INDEX ux_events_google ON events(google_event_id)
  WHERE google_event_id IS NOT NULL AND deleted_at IS NULL;

CREATE TABLE revenues (
  id                       TEXT PRIMARY KEY,
  company_id               TEXT NOT NULL REFERENCES companies(id),
  event_id                 TEXT REFERENCES events(id),
  revenue_date             TEXT NOT NULL,
  amount_kopecks           INTEGER NOT NULL,
  gross_kopecks            INTEGER,
  category                 TEXT NOT NULL CHECK (category IN ('session','other')),
  counterparty_type        TEXT NOT NULL CHECK (counterparty_type IN ('legal','individual')),
  tax_rate_bp              INTEGER NOT NULL,
  tax_base_kopecks         INTEGER NOT NULL,
  tax_deduction_kopecks    INTEGER NOT NULL DEFAULT 0,
  tax_amount_kopecks       INTEGER NOT NULL DEFAULT 0,
  is_auto                  INTEGER NOT NULL DEFAULT 0,
  is_reversed              INTEGER NOT NULL DEFAULT 0,
  reversal_of_id           TEXT REFERENCES revenues(id),
  comment                  TEXT,
  google_sheet_row         TEXT,
  created_at               TEXT NOT NULL,
  updated_at               TEXT NOT NULL,
  version                  INTEGER NOT NULL DEFAULT 1,
  deleted_at               TEXT
);

CREATE UNIQUE INDEX ux_revenues_event_auto
  ON revenues(event_id)
  WHERE event_id IS NOT NULL AND is_auto = 1 AND deleted_at IS NULL;

CREATE INDEX ix_revenues_date ON revenues(company_id, revenue_date);
CREATE INDEX ix_revenues_event ON revenues(event_id);

CREATE TABLE tax_state (
  company_id             TEXT PRIMARY KEY REFERENCES companies(id),
  deduction_limit_kopecks INTEGER NOT NULL DEFAULT 1000000,
  deduction_used_kopecks INTEGER NOT NULL DEFAULT 0,
  updated_at             TEXT NOT NULL
);

CREATE TABLE documents (
  id              TEXT PRIMARY KEY,
  company_id      TEXT NOT NULL REFERENCES companies(id),
  event_id        TEXT REFERENCES events(id),
  template_id     TEXT REFERENCES contract_templates(id),
  type            TEXT NOT NULL CHECK (type IN ('contract','act','invoice')),
  document_number TEXT NOT NULL,
  title           TEXT NOT NULL,
  file_path       TEXT,
  file_checksum   TEXT,
  size_bytes      INTEGER,
  drive_file_id   TEXT,
  signed          INTEGER NOT NULL DEFAULT 0,
  signed_date     TEXT,
  created_at      TEXT NOT NULL,
  updated_at      TEXT NOT NULL,
  version         INTEGER NOT NULL DEFAULT 1,
  deleted_at      TEXT
);

CREATE UNIQUE INDEX ux_documents_number ON documents(company_id, document_number);
CREATE INDEX ix_documents_event ON documents(event_id);

CREATE TABLE doc_counters (
  company_id TEXT NOT NULL,
  doc_type   TEXT NOT NULL,
  year       INTEGER NOT NULL,
  last_number INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (company_id, doc_type, year)
);

CREATE TABLE tasks (
  id             TEXT PRIMARY KEY,
  company_id     TEXT REFERENCES companies(id),
  user_id        TEXT REFERENCES users(id),
  event_id       TEXT REFERENCES events(id),
  institution_id TEXT REFERENCES institutions(id),
  title          TEXT NOT NULL,
  description    TEXT,
  due_at         TEXT,
  is_completed   INTEGER NOT NULL DEFAULT 0,
  repeat_rule    TEXT,
  created_at     TEXT NOT NULL,
  updated_at     TEXT NOT NULL,
  version        INTEGER NOT NULL DEFAULT 1,
  deleted_at     TEXT
);

CREATE INDEX ix_tasks_due ON tasks(is_completed, due_at);

CREATE TABLE interactions (
  id             TEXT PRIMARY KEY,
  company_id     TEXT NOT NULL REFERENCES companies(id),
  institution_id TEXT NOT NULL REFERENCES institutions(id),
  event_id       TEXT REFERENCES events(id),
  kind           TEXT NOT NULL CHECK (kind IN ('call','email','meeting','note','mailing')),
  happened_at    TEXT NOT NULL,
  summary        TEXT,
  outcome        TEXT,
  next_action_at TEXT,
  created_at     TEXT NOT NULL,
  updated_at     TEXT NOT NULL,
  version        INTEGER NOT NULL DEFAULT 1,
  deleted_at     TEXT
);

CREATE INDEX ix_interactions_institution ON interactions(institution_id, happened_at);

CREATE TABLE mailing_templates (
  id          TEXT PRIMARY KEY,
  company_id  TEXT NOT NULL REFERENCES companies(id),
  name        TEXT NOT NULL,
  subject     TEXT NOT NULL,
  body        TEXT NOT NULL,
  variables   TEXT NOT NULL DEFAULT '[]',
  created_at  TEXT NOT NULL,
  updated_at  TEXT NOT NULL,
  deleted_at  TEXT
);

CREATE TABLE mailings (
  id           TEXT PRIMARY KEY,
  company_id   TEXT NOT NULL REFERENCES companies(id),
  template_id  TEXT REFERENCES mailing_templates(id),
  subject      TEXT NOT NULL,
  body         TEXT NOT NULL,
  status       TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','sent','cancelled')),
  sent_at      TEXT,
  created_at   TEXT NOT NULL,
  updated_at   TEXT NOT NULL,
  deleted_at   TEXT
);

CREATE TABLE mailing_recipients (
  mailing_id     TEXT NOT NULL REFERENCES mailings(id),
  institution_id TEXT NOT NULL REFERENCES institutions(id),
  email          TEXT,
  status         TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','sent','failed','skipped')),
  error          TEXT,
  PRIMARY KEY (mailing_id, institution_id)
);

CREATE TABLE attachments (
  id            TEXT PRIMARY KEY,
  company_id    TEXT NOT NULL REFERENCES companies(id),
  entity_table  TEXT NOT NULL,
  entity_id     TEXT NOT NULL,
  file_name     TEXT NOT NULL,
  mime_type     TEXT NOT NULL,
  size_bytes    INTEGER NOT NULL,
  local_path    TEXT,
  drive_file_id TEXT,
  checksum_sha256 TEXT,
  created_at    TEXT NOT NULL,
  deleted_at    TEXT
);

CREATE INDEX ix_attachments_entity ON attachments(entity_table, entity_id);

CREATE TABLE change_log (
  id          TEXT PRIMARY KEY,
  table_name  TEXT NOT NULL,
  record_id   TEXT NOT NULL,
  field_name  TEXT NOT NULL,
  old_value   TEXT,
  new_value   TEXT,
  changed_by  TEXT REFERENCES users(id),
  device_id   TEXT,
  changed_at  TEXT NOT NULL
);

CREATE INDEX ix_change_log_record ON change_log(table_name, record_id, changed_at);

CREATE TABLE outbox (
  id              TEXT PRIMARY KEY,
  entity_table    TEXT NOT NULL,
  entity_id       TEXT NOT NULL,
  operation       TEXT NOT NULL CHECK (operation IN ('upsert','delete')),
  payload         TEXT,
  attempts        INTEGER NOT NULL DEFAULT 0,
  next_attempt_at TEXT,
  last_error      TEXT,
  created_at      TEXT NOT NULL
);

CREATE INDEX ix_outbox_next ON outbox(next_attempt_at);

CREATE TABLE sync_cursors (
  provider     TEXT NOT NULL,
  scope        TEXT NOT NULL,
  cursor       TEXT,
  last_sync_at TEXT,
  PRIMARY KEY (provider, scope)
);

CREATE TABLE app_settings (
  key        TEXT PRIMARY KEY,
  value      TEXT,
  updated_at TEXT NOT NULL
);
```

### 5.1 Ключи настроек

`selected_company_id`, `theme`, `revenue_mode`, `tax_base`, `reminder_day_before`, `reminder_hour_before`, `google_calendar_sync_enabled`, `google_calendar_id`, `google_drive_sync_enabled`, `google_drive_root_id`, `google_sheets_sync_enabled`, `google_sheets_spreadsheet_id`, `backup_frequency`, `ai_provider`, `ai_model`, `last_backup_at`.

API-ключи и токены **не** хранятся в `app_settings` — только в `flutter_secure_storage` / Keystore.

### 5.2 Инварианты

- `institution_snapshot` не меняется при редактировании учреждения; обновляется только по явному действию «Обновить данные в будущих мероприятиях».
- У мероприятия не может быть двух активных авто-записей выручки.
- Сумма сторно равна исходной сумме с минусом; связь через `reversal_of_id`.
- Удаление — только `deleted_at`; физическая очистка — отдельной командой «Очистить корзину».
- `total_visits` и `last_visit_date` пересчитываются из завершённых мероприятий, а не вводятся руками.

---

## 6. Оффлайн и синхронизация

- Все операции записи идут в локальную БД, затем в `outbox`.
- Сеть не требуется ни для одного экрана v1.0.
- Очередь отправляется при появлении сети и при старте приложения; экспоненциальный backoff, максимум 5 попыток, затем ручной повтор.
- Индикатор в шапке: «Не в сети», «Синхронизация…», «Есть ошибки» (тап → диагностика).
- Конфликты:
  - локальные данные — источник истины;
  - Calendar — сравнение `updated`/`remote_updated_at`, побеждает более позднее, при равенстве дат — локальное;
  - Sheets — импорт только вручную, с диффом;
  - Drive — файлы неизменяемы, конфликт решается версионированием имён.
- Часы устройства считаются доверенными в v1.0 (одно устройство). При переходе на мультиустройство — серверное время.

---

## 7. Безопасность и персональные данные

- PIN: Argon2id, соль на пользователя, 4–6 цифр; после 5 ошибок — пауза 30 секунд, после 10 — вход только по биометрии/сброс.
- Биометрия: `local_auth`, только как альтернатива PIN; при добавлении отпечатка — повторный PIN.
- БД: SQLCipher, ключ 256 бит в Keystore, не в коде и не в логах.
- Токены Google и API-ключи — `flutter_secure_storage`.
- `FLAG_SECURE` на экранах с PIN и документами (отключение скриншотов).
- Логи не содержат ФИО, телефонов, сумм и токенов.
- Персональные данные детей (ФИО) **не хранятся** — только количество.
- Google Drive: передача документов с ПДн за пределы РФ — риск по 152-ФЗ. До юридического заключения рекомендуется Yandex Disk либо хранение в Drive только обезличенных документов (см. раздел 11).
- Перед ИИ — редактирование ПДн (раздел 4.4).
- Удаление компании/сброс — с подтверждением вводом слова `УДАЛИТЬ`.

---

## 8. Нефункциональные требования

| Параметр | Значение |
|---|---|
| Android | minSdk 26, targetSdk 35 |
| Холодный старт | < 3 с на устройстве среднего класса (4 ГБ RAM) |
| Отклик интерфейса | < 200 мс на действие |
| Анимации | 60 FPS, переходы 300 мс |
| Объём базы | 10 000 учреждений и 50 000 мероприятий без деградации |
| Списки | пагинация по 50, поиск < 300 мс |
| PDF | генерация < 2 с на документ |
| Ориентация | портретная; ландшафт — опционально |
| Ширина экрана | 320–720 dp |
| Язык | русский; строки вынесены в ARB |
| Тема | тёмная/светлая/системная, токены из `src/styles.css` |
| Тесты | unit на деньги/налог/статусы, widget на карточки, integration на CRUD и импорт |

### 8.1 Технические решения

- Flutter, Dart 3.
- Состояние: Riverpod. Навигация: go_router.
- БД: Drift + `sqlcipher_flutter_libs` (вместо sqflite — типизированные запросы и миграции).
- PDF: `pdf` + `printing`; шрифты PT Sans с кириллицей в ассетах.
- Файлы/импорт: `file_picker`, `csv`, `excel`.
- Google: `google_sign_in`, `googleapis`.
- Уведомления: `flutter_local_notifications` + `workmanager`.
- Безопасность: `flutter_secure_storage`, `local_auth`.
- Локализация: `intl` + ARB.

---

## 9. Критерии приёмки

1. **Часовые пояса.** Мероприятие 12.10.2026 09:00 в Уфе создаёт событие в Google Calendar с 09:00 UTC+5; в НН — с 09:00 UTC+3; после смены таймзоны компании старые события не сдвигаются.
2. **Деньги.** 25 детей × 250 ₽, доля 25% → gross 6 250,00 ₽, доля 1 562,50 ₽, net 4 687,50 ₽; сумма совпадает в карточке, дашборде и PDF.
3. **Налог.** При базе 4 687,50 ₽ и юрлице налог 187,50 ₽ с вычетом; после исчерпания 10 000 ₽ — 281,25 ₽; сумма вычета не уходит в минус.
4. **Идемпотентность.** Повторное завершение мероприятия не создаёт вторую авто-запись; отмена создаёт сторно ровно на исходную сумму; отчёт за прошлый месяц после сторно воспроизводится.
5. **Оффлайн.** Полный цикл «создать учреждение → мероприятие → завершить → сформировать PDF» проходит в авиарежиме; после включения сети изменения уходят без дублей.
6. **Импорт.** XLSX с 500 строками и несовпадающими колонками импортируется после ручного сопоставления; ошибочные строки попадают в отчёт, валидные — в базу.
7. **Поиск.** На 10 000 учреждений поиск по телефону и названию возвращает результат < 300 мс.
8. **Документы.** Договор генерируется из мероприятия с подстановкой всех переменных, кириллица не ломается, номер уникален в рамках компании и года.
9. **Безопасность.** PIN не хранится в открытом виде; файл БД без ключа не открывается; токены не видны в логах; скриншот экрана PIN заблокирован.
10. **Смена компании.** Данные Уфы и НН не пересекаются ни в одном списке, отчёте и экспорте.
11. **Уведомления.** Напоминание приходит за 24 часа и за 1 час; при включённом Calendar дублей нет.
12. **Синхронизация Calendar.** Правка времени в приложении обновляет событие; правка в календаре подтягивается при следующем запуске; конфликт виден в диагностике.
13. **Восстановление.** Бэкап восстанавливается на чистом устройстве и содержит все компании, мероприятия, учреждения и документы.
14. **Производительность.** Холодный старт < 3 с, прокрутка списка 10 000 записей без фризов.
15. **Доступность.** Все интерактивные элементы ≥ 48×48 dp, контраст текста ≥ 4.5:1, свайп-действия дублируются в меню.

---

## 10. Оценка

Оценка для одного Flutter-разработчика, без дизайнера (дизайн-токены уже есть в прототипе), включая тесты и релизную сборку.

| Этап | Оценка |
|---|---|
| v1.0 | 40–55 рабочих дней |
| v1.1 | 15–20 рабочих дней |
| v2 | 35–50 рабочих дней |
| **Итого до v1.1** | **55–75 рабочих дней** |

Риски, влияющие на срок: юридическая проверка шаблонов договоров, доступ к реальным Excel-файлам Марины, верификация Google OAuth для продакшена (несколько дней), политика Play Store по биометрии и уведомлениям.

---

## 11. Открытые бизнес-вопросы (нужен ответ Марины)

1. **Кто платит исполнителю:** сад перечисляет сумму за вычетом своего процента или родители платят напрямую? От этого зависит налоговая база по умолчанию.
2. **Налоговая база:** подтвердить у бухгалтера — `received` (по умолчанию) или `gross`. Это влияет на сумму налога, а не на код.
3. **Договор:** с садом или с родителями? Кто подписывает и нужны ли реквизиты сада (ИНН) в шаблоне?
4. **Юрлицо/физлицо:** все ли учреждения — юрлица? Бывают ли физлица-заказчики (частные центры)?
5. **Документы:** кто утверждает тексты 4 шаблонов? Без этого генерация PDF юридически бессмысленна.
6. **Google:** один аккаунт на обе компании или разные? Чей аккаунт будет владельцем Drive-папок?
7. **152-ФЗ:** допустимо ли хранить документы с ПДн в Google Drive, или нужен российский провайдер (Yandex Disk)?
8. **Мультиустройство:** планируется ли работа с телефона и планшета одновременно в первый год? Если да — backend нужен в v1.0, и оценка меняется.
9. **Чеки НПД:** кто формирует чеки в «Мой налог» — Марина вручную или бухгалтер? Нужен ли экспорт-подсказка со списком сумм за месяц?

---

## 12. Ссылки

- визуальный референс и токены: `src/styles.css`, `src/data.js`;
- макет-ориентир: https://cosmic-website-1--preview.poehali.dev/ (веб, не мобильный UI).

---

## 13. Статус реализации (21.10.2026)

Реализован проверяемый скелет v1.1 в `app/`:

- доменная логика: деньги в копейках, доли в bp, НПД с вычетом, сторно, таймзоны;
- две реализации репозитория: SQLite для устройства и in-memory для веб-демо;
- экраны: выбор компании, главная, расписание, база, документы, выручка;
- быстрое добавление мероприятия, учреждения и выручки через FAB;
- расписание: поиск по учреждению, адресу, контакту, телефону, программе и заметкам, фильтр по учреждению;
- база учреждений: фильтры по статусу, городу, району и тегу, сортировка по названию/городу/последнему визиту/числу сеансов, редактирование статуса, тегов и заметок, действие «проверено», массовый выбор с групповой сменой статуса и удалением;
- генерация договора, акта и счёта в PDF с кириллицей и запись в архив;
- архив документов: поиск по названию/номеру/дате, сортировка (новые, старые, номер, название), отметка «подписан», мягкое удаление с подтверждением;
- открытие PDF из архива: системный просмотрщик на Android, новая вкладка браузера на вебе;
- русская локализация Material (дата/время, 24-часовой формат);
- русские склонения для детей, программ, сеансов и документов;
- экспорт учреждений и выручки в XLSX/CSV с учётом текущих фильтров;
- PDF-отчёт по выручке: сводка месяца, НПД, вычет, 6 месяцев и операции;
- импорт учреждений из XLSX/CSV: автосопоставление колонок, предпросмотр, лог ошибок, политика дубликатов (пропустить / обновить / создать);
- профиль: изменение имени и PIN-код (4–6 цифр) с хешированием Argon2id (19 МиБ, 2 итерации), запрос при запуске, блокировка по кнопке, пауза после 5 ошибок (30 с) и 10 ошибок (5 мин), вход по отпечатку как альтернатива PIN (Android);
- автоблокировка при возврате в приложение после 30 секунд в фоне; `FLAG_SECURE` на Android отключает скриншоты;
- полная резервная копия всех таблиц в JSON и восстановление с заменой данных (на устройстве);
- локальные напоминания о мероприятиях: включение, выбор интервала (15 минут — 1 день), планирование на 60 дней вперёд, перепланирование при изменении событий, восстановление после перезагрузки Android;
- шифрование базы: SQLCipher, ключ 256 бит в `flutter_secure_storage` (Android Keystore), автоматическая миграция прежней незашифрованной базы через JSON-бэкап; `allowBackup=false`, proguard-правила для SQLCipher.

Проверка:

- `flutter analyze` — без замечаний;
- `flutter test` — 57 тестов проходит;
- `flutter build web --release` — успешно;
- `flutter build apk --debug` и `--release` — успешно, `minSdk = 26`;
- ручной прогон в браузере 430×932: создание мероприятия, завершение, авто-начисление, сторно, смена компании, генерация договора/акта/счёта, экспорт XLSX/CSV, импорт CSV с дубликатом, установка PIN, блокировка и разблокировка, экран резервной копии, экран напоминаний (на вебе отключён), профиль с PIN и переключателем биометрии, пауза после пяти неверных PIN с обратным отсчётом и разблокировка верным PIN после паузы, поиск и фильтр расписания по учреждению, сортировка, фильтры базы по статусу/городу/району/тегу и массовая смена статуса с удалением, поиск и сортировка архива, отметка документа подписанным, мягкое удаление, открытие сформированного PDF и PDF-отчёта по выручке в новой вкладке (проверено `%PDF-` в blob); на вебе используется in-memory база.

Исправленные при проверке дефекты: невидимые карточки расписания из-за `CrossAxisAlignment.stretch` в `ListView`, отсутствие FAB, склонения, английские дата/время, гонка при выборе шаблона договора.

Ограничения скелета: нет Google Calendar/Drive/Sheets и ИИ; биометрия, доставка уведомлений и открытие зашифрованной базы проверены только сборкой APK, но не на физическом устройстве; локальные уведомления доступны только на Android и используют неточное планирование (без разрешения на точные будильники); PIN новых установок хранится хешем Argon2id, ранее созданные PBKDF2-хеши проверяются, но не обновляются автоматически; после 10 ошибок действует пауза 5 минут вместо входа только по биометрии/сброса; полная резервная копия доступна только на устройстве (в веб-демо память не сохраняется); импорт пока поддерживает только учреждения и не создаёт историю изменений по каждой строке; PDF открывается из архива (на вебе — только до перезагрузки страницы), но шаринг PDF пока не реализован.
