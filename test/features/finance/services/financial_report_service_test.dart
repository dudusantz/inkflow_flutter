import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/finance/domain/financial_record.dart';
import 'package:inkflow/features/finance/services/financial_report_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('gera relatório financeiro por período', () async {
    final bytes = await FinancialReportService.build(
      start: DateTime(2026, 9, 1),
      end: DateTime(2026, 9, 30),
      records: [
        FinancialRecord(
          id: '1',
          type: FinancialRecordType.payment,
          description: 'Sessão',
          amount: 500,
          date: DateTime(2026, 9, 10),
          category: 'PIX',
          status: 'PAGO',
        ),
        FinancialRecord(
          id: '2',
          type: FinancialRecordType.expense,
          description: 'Materiais',
          amount: 120,
          date: DateTime(2026, 9, 11),
          category: 'MATERIAIS',
          status: 'PAGO',
        ),
      ],
    );

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
