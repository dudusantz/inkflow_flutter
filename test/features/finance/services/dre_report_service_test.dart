import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/finance/domain/dre_summary.dart';
import 'package:inkflow/features/finance/services/dre_report_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('gera DRE em PDF', () async {
    final bytes = await DreReportService.build(
      dre: const DreSummary(
        grossRevenue: 1000,
        taxes: 50,
        serviceCosts: 200,
        operatingExpenses: 250,
        investments: 100,
        pendingRevenue: 0,
        taxesAreEstimated: true,
      ),
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 10, 31),
      studioName: 'InkFlow Studio',
    );

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
