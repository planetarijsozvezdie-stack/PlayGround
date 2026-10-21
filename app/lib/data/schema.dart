const List<String> schemaStatements = [
  '''
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
)''',
  '''
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
)''',
  '''
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
)''',
  '''
CREATE UNIQUE INDEX ux_institutions_natural
  ON institutions(company_id, type, number, city)
  WHERE deleted_at IS NULL AND number IS NOT NULL''',
  'CREATE INDEX ix_institutions_company ON institutions(company_id, deleted_at)',
  'CREATE INDEX ix_institutions_city ON institutions(company_id, city, type)',
  '''
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
)''',
  '''
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
)''',
  '''
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
)''',
  'CREATE INDEX ix_events_calendar ON events(company_id, event_date, time_start)',
  'CREATE INDEX ix_events_status ON events(company_id, status, event_date)',
  '''
CREATE UNIQUE INDEX ux_events_google ON events(google_event_id)
  WHERE google_event_id IS NOT NULL AND deleted_at IS NULL''',
  '''
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
)''',
  '''
CREATE UNIQUE INDEX ux_revenues_event_auto
  ON revenues(event_id)
  WHERE event_id IS NOT NULL AND is_auto = 1 AND deleted_at IS NULL''',
  'CREATE INDEX ix_revenues_date ON revenues(company_id, revenue_date)',
  'CREATE INDEX ix_revenues_event ON revenues(event_id)',
  '''
CREATE TABLE tax_state (
  company_id              TEXT PRIMARY KEY REFERENCES companies(id),
  deduction_limit_kopecks INTEGER NOT NULL DEFAULT 1000000,
  deduction_used_kopecks  INTEGER NOT NULL DEFAULT 0,
  updated_at              TEXT NOT NULL
)''',
  '''
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
)''',
  'CREATE UNIQUE INDEX ux_documents_number ON documents(company_id, document_number)',
  'CREATE INDEX ix_documents_event ON documents(event_id)',
  '''
CREATE TABLE doc_counters (
  company_id  TEXT NOT NULL,
  doc_type    TEXT NOT NULL,
  year        INTEGER NOT NULL,
  last_number INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (company_id, doc_type, year)
)''',
  '''
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
)''',
  'CREATE INDEX ix_tasks_due ON tasks(is_completed, due_at)',
  '''
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
)''',
  'CREATE INDEX ix_interactions_institution ON interactions(institution_id, happened_at)',
  '''
CREATE TABLE mailing_templates (
  id         TEXT PRIMARY KEY,
  company_id TEXT NOT NULL REFERENCES companies(id),
  name       TEXT NOT NULL,
  subject    TEXT NOT NULL,
  body       TEXT NOT NULL,
  variables  TEXT NOT NULL DEFAULT '[]',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT
)''',
  '''
CREATE TABLE mailings (
  id          TEXT PRIMARY KEY,
  company_id  TEXT NOT NULL REFERENCES companies(id),
  template_id TEXT REFERENCES mailing_templates(id),
  subject     TEXT NOT NULL,
  body        TEXT NOT NULL,
  status      TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','sent','cancelled')),
  sent_at     TEXT,
  created_at  TEXT NOT NULL,
  updated_at  TEXT NOT NULL,
  deleted_at  TEXT
)''',
  '''
CREATE TABLE mailing_recipients (
  mailing_id     TEXT NOT NULL REFERENCES mailings(id),
  institution_id TEXT NOT NULL REFERENCES institutions(id),
  email          TEXT,
  status         TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','sent','failed','skipped')),
  error          TEXT,
  PRIMARY KEY (mailing_id, institution_id)
)''',
  '''
CREATE TABLE attachments (
  id              TEXT PRIMARY KEY,
  company_id      TEXT NOT NULL REFERENCES companies(id),
  entity_table    TEXT NOT NULL,
  entity_id       TEXT NOT NULL,
  file_name       TEXT NOT NULL,
  mime_type       TEXT NOT NULL,
  size_bytes      INTEGER NOT NULL,
  local_path      TEXT,
  drive_file_id   TEXT,
  checksum_sha256 TEXT,
  created_at      TEXT NOT NULL,
  deleted_at      TEXT
)''',
  'CREATE INDEX ix_attachments_entity ON attachments(entity_table, entity_id)',
  '''
CREATE TABLE change_log (
  id         TEXT PRIMARY KEY,
  table_name TEXT NOT NULL,
  record_id  TEXT NOT NULL,
  field_name TEXT NOT NULL,
  old_value  TEXT,
  new_value  TEXT,
  changed_by TEXT REFERENCES users(id),
  device_id  TEXT,
  changed_at TEXT NOT NULL
)''',
  'CREATE INDEX ix_change_log_record ON change_log(table_name, record_id, changed_at)',
  '''
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
)''',
  'CREATE INDEX ix_outbox_next ON outbox(next_attempt_at)',
  '''
CREATE TABLE sync_cursors (
  provider     TEXT NOT NULL,
  scope        TEXT NOT NULL,
  cursor       TEXT,
  last_sync_at TEXT,
  PRIMARY KEY (provider, scope)
)''',
  '''
CREATE TABLE app_settings (
  key        TEXT PRIMARY KEY,
  value      TEXT,
  updated_at TEXT NOT NULL
)''',
];
