import 'money.dart';

class EventPricing {
  const EventPricing({
    required this.grossKopecks,
    required this.institutionShareKopecks,
    required this.netKopecks,
  });

  factory EventPricing.compute({
    required int childrenCount,
    required int pricePerChildKopecks,
    required int institutionPercentBp,
  }) {
    assert(childrenCount >= 0);
    assert(pricePerChildKopecks >= 0);
    assert(institutionPercentBp >= 0 && institutionPercentBp <= 10000);
    final gross = childrenCount * pricePerChildKopecks;
    final share = roundHalfUpDiv(gross * institutionPercentBp, 10000);
    return EventPricing(
      grossKopecks: gross,
      institutionShareKopecks: share,
      netKopecks: gross - share,
    );
  }

  final int grossKopecks;
  final int institutionShareKopecks;
  final int netKopecks;
}
