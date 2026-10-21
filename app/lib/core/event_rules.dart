enum EventStatus {
  scheduled,
  completed,
  cancelled;

  String get label => switch (this) {
    EventStatus.scheduled => 'Запланировано',
    EventStatus.completed => 'Завершено',
    EventStatus.cancelled => 'Отменено',
  };

  static EventStatus fromDb(String value) => values.firstWhere(
    (e) => e.name == value,
    orElse: () => EventStatus.scheduled,
  );
}

enum RevenueMode {
  auto,
  confirm;

  static RevenueMode fromDb(String value) =>
      value == 'confirm' ? RevenueMode.confirm : RevenueMode.auto;
}

enum TaxBaseMode {
  received,
  gross;

  static TaxBaseMode fromDb(String value) =>
      value == 'gross' ? TaxBaseMode.gross : TaxBaseMode.received;
}

enum RevenueEffect { none, createAuto, reverseAuto, createConfirmationTask }

class EventRules {
  static RevenueEffect onStatusChange(
    EventStatus from,
    EventStatus to, {
    RevenueMode mode = RevenueMode.auto,
  }) {
    if (from == to) return RevenueEffect.none;
    if (to == EventStatus.completed) {
      return mode == RevenueMode.auto
          ? RevenueEffect.createAuto
          : RevenueEffect.createConfirmationTask;
    }
    if (from == EventStatus.completed &&
        (to == EventStatus.scheduled || to == EventStatus.cancelled)) {
      return RevenueEffect.reverseAuto;
    }
    return RevenueEffect.none;
  }
}
