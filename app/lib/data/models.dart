import 'dart:convert';

import '../core/event_rules.dart';
import '../core/pricing.dart';
import '../core/tax.dart';
import '../core/ru_format.dart';

enum InstitutionType {
  kindergarten,
  school,
  other;

  String get label => switch (this) {
    InstitutionType.kindergarten => 'Детский сад',
    InstitutionType.school => 'Школа',
    InstitutionType.other => 'Прочее',
  };

  static InstitutionType fromDb(String value) => values.firstWhere(
    (e) => e.name == value,
    orElse: () => InstitutionType.other,
  );
}

enum InstitutionStatus {
  active,
  inactive,
  verified;

  String get label => switch (this) {
    InstitutionStatus.active => 'Активный',
    InstitutionStatus.inactive => 'Неактивный',
    InstitutionStatus.verified => 'Проверено',
  };

  static InstitutionStatus fromDb(String value) => values.firstWhere(
    (e) => e.name == value,
    orElse: () => InstitutionStatus.active,
  );
}

class Company {
  const Company({
    required this.id,
    required this.name,
    required this.shortName,
    required this.city,
    required this.region,
    required this.timezone,
    required this.inn,
    required this.ogrnip,
    required this.legalAddress,
    required this.bankDetails,
    required this.phone,
    required this.email,
    required this.signer,
    required this.accentHex,
  });

  final String id;
  final String name;
  final String shortName;
  final String city;
  final String region;
  final String timezone;
  final String inn;
  final String ogrnip;
  final String legalAddress;
  final String bankDetails;
  final String phone;
  final String email;
  final String signer;
  final String accentHex;
}

class Institution {
  const Institution({
    required this.id,
    required this.companyId,
    required this.type,
    required this.number,
    required this.name,
    required this.city,
    required this.district,
    required this.address,
    required this.contactPerson,
    required this.position,
    required this.phonePrimary,
    required this.phoneSecondary,
    required this.email,
    required this.website,
    required this.groupsCount,
    required this.hallCapacity,
    required this.notes,
    required this.lastVisitDate,
    required this.totalVisits,
    required this.status,
    required this.tags,
    required this.counterparty,
    required this.externalId,
  });

  final String id;
  final String companyId;
  final InstitutionType type;
  final String number;
  final String name;
  final String city;
  final String district;
  final String address;
  final String contactPerson;
  final String position;
  final String phonePrimary;
  final String phoneSecondary;
  final String email;
  final String website;
  final int? groupsCount;
  final int? hallCapacity;
  final String notes;
  final DateTime? lastVisitDate;
  final int totalVisits;
  final InstitutionStatus status;
  final List<String> tags;
  final CounterpartyType counterparty;
  final String externalId;

  String get displayName => number.isEmpty
      ? name
      : '${type == InstitutionType.school
            ? 'Школа'
            : type == InstitutionType.kindergarten
            ? 'Детский сад'
            : ''} №$number';

  String get searchBlob => [
    name,
    number,
    city,
    district,
    address,
    contactPerson,
    phonePrimary,
    phoneSecondary,
    email,
    tags.join(' '),
  ].join(' ').toLowerCase();

  Institution copyWith({
    InstitutionType? type,
    String? number,
    String? name,
    String? city,
    String? district,
    String? address,
    String? contactPerson,
    String? position,
    String? phonePrimary,
    String? phoneSecondary,
    String? email,
    String? website,
    int? groupsCount,
    int? hallCapacity,
    String? notes,
    InstitutionStatus? status,
    List<String>? tags,
    CounterpartyType? counterparty,
  }) => Institution(
    id: id,
    companyId: companyId,
    type: type ?? this.type,
    number: number ?? this.number,
    name: name ?? this.name,
    city: city ?? this.city,
    district: district ?? this.district,
    address: address ?? this.address,
    contactPerson: contactPerson ?? this.contactPerson,
    position: position ?? this.position,
    phonePrimary: phonePrimary ?? this.phonePrimary,
    phoneSecondary: phoneSecondary ?? this.phoneSecondary,
    email: email ?? this.email,
    website: website ?? this.website,
    groupsCount: groupsCount ?? this.groupsCount,
    hallCapacity: hallCapacity ?? this.hallCapacity,
    notes: notes ?? this.notes,
    lastVisitDate: lastVisitDate,
    totalVisits: totalVisits,
    status: status ?? this.status,
    tags: tags ?? this.tags,
    counterparty: counterparty ?? this.counterparty,
    externalId: externalId,
  );
}

class Event {
  const Event({
    required this.id,
    required this.companyId,
    required this.institutionId,
    required this.institutionName,
    required this.institutionAddress,
    required this.contactPerson,
    required this.contactPhone,
    required this.date,
    required this.timeStart,
    required this.durationMinutes,
    required this.timezone,
    required this.programName,
    required this.childrenCount,
    required this.pricePerChildKopecks,
    required this.institutionPercentBp,
    required this.grossKopecks,
    required this.institutionShareKopecks,
    required this.netKopecks,
    required this.status,
    required this.notes,
    required this.googleEventId,
  });

  factory Event.draft({
    required String id,
    required String companyId,
    required Institution institution,
    required DateTime date,
    required String timeStart,
    required String timezone,
    required String programName,
    required int childrenCount,
    required int pricePerChildKopecks,
    required int institutionPercentBp,
    String notes = '',
    int durationMinutes = 40,
  }) {
    final pricing = EventPricing.compute(
      childrenCount: childrenCount,
      pricePerChildKopecks: pricePerChildKopecks,
      institutionPercentBp: institutionPercentBp,
    );
    return Event(
      id: id,
      companyId: companyId,
      institutionId: institution.id,
      institutionName: institution.displayName,
      institutionAddress: '${institution.city}, ${institution.address}',
      contactPerson: institution.contactPerson,
      contactPhone: institution.phonePrimary,
      date: DateTime(date.year, date.month, date.day),
      timeStart: timeStart,
      durationMinutes: durationMinutes,
      timezone: timezone,
      programName: programName,
      childrenCount: childrenCount,
      pricePerChildKopecks: pricePerChildKopecks,
      institutionPercentBp: institutionPercentBp,
      grossKopecks: pricing.grossKopecks,
      institutionShareKopecks: pricing.institutionShareKopecks,
      netKopecks: pricing.netKopecks,
      status: EventStatus.scheduled,
      notes: notes,
      googleEventId: null,
    );
  }

  final String id;
  final String companyId;
  final String? institutionId;
  final String institutionName;
  final String institutionAddress;
  final String contactPerson;
  final String contactPhone;
  final DateTime date;
  final String timeStart;
  final int durationMinutes;
  final String timezone;
  final String programName;
  final int childrenCount;
  final int pricePerChildKopecks;
  final int institutionPercentBp;
  final int grossKopecks;
  final int institutionShareKopecks;
  final int netKopecks;
  final EventStatus status;
  final String notes;
  final String? googleEventId;

  String get snapshotJson => jsonEncode({
    'name': institutionName,
    'address': institutionAddress,
    'contact': contactPerson,
    'phone': contactPhone,
  });

  String get timeLabel => '${isoDate(date)} $timeStart · $durationMinutes мин';

  Event copyWith({
    EventStatus? status,
    String? id,
    String? timeStart,
    DateTime? date,
    String? programName,
    int? childrenCount,
    int? pricePerChildKopecks,
    int? institutionPercentBp,
    String? notes,
    String? googleEventId,
    bool clearGoogleEventId = false,
    Institution? institution,
  }) {
    final children = childrenCount ?? this.childrenCount;
    final price = pricePerChildKopecks ?? this.pricePerChildKopecks;
    final percent = institutionPercentBp ?? this.institutionPercentBp;
    final pricing = EventPricing.compute(
      childrenCount: children,
      pricePerChildKopecks: price,
      institutionPercentBp: percent,
    );
    return Event(
      id: id ?? this.id,
      companyId: companyId,
      institutionId: institution?.id ?? institutionId,
      institutionName: institution?.displayName ?? institutionName,
      institutionAddress: institution == null
          ? institutionAddress
          : '${institution.city}, ${institution.address}',
      contactPerson: institution?.contactPerson ?? contactPerson,
      contactPhone: institution?.phonePrimary ?? contactPhone,
      date: date ?? this.date,
      timeStart: timeStart ?? this.timeStart,
      durationMinutes: durationMinutes,
      timezone: timezone,
      programName: programName ?? this.programName,
      childrenCount: children,
      pricePerChildKopecks: price,
      institutionPercentBp: percent,
      grossKopecks: pricing.grossKopecks,
      institutionShareKopecks: pricing.institutionShareKopecks,
      netKopecks: pricing.netKopecks,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      googleEventId: clearGoogleEventId
          ? null
          : (googleEventId ?? this.googleEventId),
    );
  }
}

class Revenue {
  const Revenue({
    required this.id,
    required this.companyId,
    required this.eventId,
    required this.date,
    required this.amountKopecks,
    required this.grossKopecks,
    required this.category,
    required this.counterparty,
    required this.taxRateBp,
    required this.taxBaseKopecks,
    required this.taxDeductionKopecks,
    required this.taxAmountKopecks,
    required this.isAuto,
    required this.isReversed,
    required this.reversalOfId,
    required this.comment,
  });

  final String id;
  final String companyId;
  final String? eventId;
  final DateTime date;
  final int amountKopecks;
  final int? grossKopecks;
  final String category;
  final CounterpartyType counterparty;
  final int taxRateBp;
  final int taxBaseKopecks;
  final int taxDeductionKopecks;
  final int taxAmountKopecks;
  final bool isAuto;
  final bool isReversed;
  final String? reversalOfId;
  final String comment;
}

class DashboardStats {
  const DashboardStats({
    required this.completedSessions,
    required this.revenueKopecks,
    required this.plannedEvents,
    required this.taxKopecks,
    required this.deductionRemainingKopecks,
  });

  final int completedSessions;
  final int revenueKopecks;
  final int plannedEvents;
  final int taxKopecks;
  final int deductionRemainingKopecks;
}

class ProgramRecord {
  const ProgramRecord({
    required this.id,
    required this.companyId,
    required this.name,
    required this.description,
    required this.audience,
    required this.ageGroup,
    required this.durationMinutes,
    required this.isActive,
  });

  final String id;
  final String companyId;
  final String name;
  final String description;
  final InstitutionType audience;
  final String ageGroup;
  final int durationMinutes;
  final bool isActive;
}

class TemplateRecord {
  const TemplateRecord({
    required this.id,
    required this.companyId,
    required this.type,
    required this.name,
    required this.body,
  });

  final String id;
  final String companyId;
  final InstitutionType type;
  final String name;
  final String body;
}

class DocumentRecord {
  const DocumentRecord({
    required this.id,
    required this.companyId,
    required this.eventId,
    required this.type,
    required this.number,
    required this.title,
    required this.filePath,
    required this.sizeBytes,
    required this.createdAt,
    this.signed = false,
    this.signedDate,
    this.driveFileId,
  });

  final String id;
  final String companyId;
  final String? eventId;
  final String type;
  final String number;
  final String title;
  final String? filePath;
  final int? sizeBytes;
  final DateTime createdAt;
  final bool signed;
  final DateTime? signedDate;
  final String? driveFileId;

  DocumentRecord copyWith({
    bool? signed,
    DateTime? signedDate,
    String? driveFileId,
  }) => DocumentRecord(
    id: id,
    companyId: companyId,
    eventId: eventId,
    type: type,
    number: number,
    title: title,
    filePath: filePath,
    sizeBytes: sizeBytes,
    createdAt: createdAt,
    signed: signed ?? this.signed,
    signedDate: signedDate ?? this.signedDate,
    driveFileId: driveFileId ?? this.driveFileId,
  );
}

class ChangeEntry {
  const ChangeEntry({
    required this.field,
    required this.oldValue,
    required this.newValue,
    required this.changedAt,
  });

  final String field;
  final String oldValue;
  final String newValue;
  final DateTime changedAt;
}
