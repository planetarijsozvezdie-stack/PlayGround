import 'money.dart';

enum CounterpartyType {
  legal,
  individual;

  String get label => this == CounterpartyType.legal ? 'Юрлицо' : 'Физлицо';

  static CounterpartyType fromDb(String value) => values.firstWhere(
    (e) => e.name == value,
    orElse: () => CounterpartyType.legal,
  );
}

class TaxResult {
  const TaxResult({
    required this.rateBp,
    required this.taxBaseKopecks,
    required this.deductionAppliedKopecks,
    required this.taxAmountKopecks,
    required this.deductionRemainingKopecks,
  });

  final int rateBp;
  final int taxBaseKopecks;
  final int deductionAppliedKopecks;
  final int taxAmountKopecks;
  final int deductionRemainingKopecks;
}

class TaxCalculator {
  static const int deductionLimitKopecks = 1000000;

  static int rateBpFor(CounterpartyType type) =>
      type == CounterpartyType.legal ? 600 : 400;

  static int deductionBpFor(int rateBp) => rateBp == 600 ? 200 : 100;

  static TaxResult calculate({
    required int taxBaseKopecks,
    required CounterpartyType counterparty,
    required int deductionRemainingKopecks,
    int? rateBpOverride,
  }) {
    assert(taxBaseKopecks >= 0, 'tax base must be non-negative');
    final rateBp = rateBpOverride ?? rateBpFor(counterparty);
    final remaining = deductionRemainingKopecks.clamp(0, deductionLimitKopecks);
    final possibleDeduction = roundHalfUpDiv(
      taxBaseKopecks * deductionBpFor(rateBp),
      10000,
    );
    final deduction = possibleDeduction < remaining
        ? possibleDeduction
        : remaining;
    final grossTax = roundHalfUpDiv(taxBaseKopecks * rateBp, 10000);
    final tax = (grossTax - deduction).clamp(0, grossTax);
    return TaxResult(
      rateBp: rateBp,
      taxBaseKopecks: taxBaseKopecks,
      deductionAppliedKopecks: deduction,
      taxAmountKopecks: tax,
      deductionRemainingKopecks: remaining - deduction,
    );
  }

  static String describe(TaxResult result) {
    final effective = result.rateBp / 100;
    return '${effective.toStringAsFixed(0)}% · вычет '
        '${formatKopecks(result.deductionAppliedKopecks)}';
  }
}

int addDeductionUsed(int used, int applied) =>
    (used + applied).clamp(0, TaxCalculator.deductionLimitKopecks);
