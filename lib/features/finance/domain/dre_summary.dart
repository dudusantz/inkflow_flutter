import 'package:inkflow/features/finance/domain/financial_record.dart';

class DreSummary {
  final double grossRevenue;
  final double taxes;
  final double serviceCosts;
  final double operatingExpenses;
  final double investments;
  final double pendingRevenue;
  final bool taxesAreEstimated;

  const DreSummary({
    required this.grossRevenue,
    required this.taxes,
    required this.serviceCosts,
    required this.operatingExpenses,
    required this.investments,
    required this.pendingRevenue,
    required this.taxesAreEstimated,
  });

  double get netRevenue => grossRevenue - taxes;
  double get grossProfit => netRevenue - serviceCosts;
  double get netResult => grossProfit - operatingExpenses;
  double get netMargin =>
      grossRevenue == 0 ? 0 : (netResult / grossRevenue) * 100;

  factory DreSummary.fromRecords(
    Iterable<FinancialRecord> records, {
    required double taxRate,
  }) {
    var grossRevenue = 0.0;
    var serviceCosts = 0.0;
    var operatingExpenses = 0.0;
    var investments = 0.0;
    var pendingRevenue = 0.0;
    var recordedTaxes = 0.0;

    for (final record in records) {
      if (record.type == FinancialRecordType.payment) {
        if (record.status == 'PAGO') {
          grossRevenue += record.amount;
        } else if (record.status == 'PENDENTE' || record.status == 'PARCIAL') {
          pendingRevenue += record.amount;
        }
        continue;
      }

      switch (record.dreClass) {
        case 'VARIABLE_COST':
          serviceCosts += record.amount;
          break;
        case 'TAX':
          recordedTaxes += record.amount;
          break;
        case 'INVESTMENT':
          investments += record.amount;
          break;
        default:
          operatingExpenses += record.amount;
      }
    }

    final safeTaxRate = taxRate.clamp(0, 100).toDouble();
    return DreSummary(
      grossRevenue: grossRevenue,
      taxes:
          recordedTaxes > 0 ? recordedTaxes : grossRevenue * safeTaxRate / 100,
      serviceCosts: serviceCosts,
      operatingExpenses: operatingExpenses,
      investments: investments,
      pendingRevenue: pendingRevenue,
      taxesAreEstimated: recordedTaxes == 0,
    );
  }
}
