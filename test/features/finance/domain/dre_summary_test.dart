import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/finance/domain/dre_summary.dart';
import 'package:inkflow/features/finance/domain/financial_record.dart';

void main() {
  test('calcula o DRE apenas com recebimentos pagos', () {
    final records = [
      FinancialRecord(
        id: '1',
        type: FinancialRecordType.payment,
        description: 'Sessão paga',
        amount: 1000,
        date: DateTime(2026, 10, 1),
        category: 'PIX',
        status: 'PAGO',
      ),
      FinancialRecord(
        id: '2',
        type: FinancialRecordType.payment,
        description: 'Sessão pendente',
        amount: 300,
        date: DateTime(2026, 10, 2),
        category: 'PIX',
        status: 'PENDENTE',
      ),
      FinancialRecord(
        id: '3',
        type: FinancialRecordType.expense,
        description: 'Tintas',
        amount: 200,
        date: DateTime(2026, 10, 3),
        category: 'MATERIAIS',
        status: 'PAGO',
        dreClass: 'VARIABLE_COST',
      ),
      FinancialRecord(
        id: '4',
        type: FinancialRecordType.expense,
        description: 'Aluguel',
        amount: 250,
        date: DateTime(2026, 10, 4),
        category: 'ALUGUEL',
        status: 'PAGO',
      ),
    ];

    final dre = DreSummary.fromRecords(records, taxRate: 5);

    expect(dre.grossRevenue, 1000);
    expect(dre.taxes, 50);
    expect(dre.serviceCosts, 200);
    expect(dre.operatingExpenses, 250);
    expect(dre.pendingRevenue, 300);
    expect(dre.netResult, 500);
    expect(dre.netMargin, 50);
  });

  test('limita a alíquota ao intervalo válido', () {
    final dre = DreSummary.fromRecords(
      [
        FinancialRecord(
          id: '1',
          type: FinancialRecordType.payment,
          description: 'Sessão',
          amount: 100,
          date: DateTime(2026, 10, 1),
          category: 'PIX',
          status: 'PAGO',
        ),
      ],
      taxRate: 120,
    );

    expect(dre.taxes, 100);
    expect(dre.netResult, 0);
  });

  test('usa imposto lançado e mantém investimento fora do resultado', () {
    final records = [
      FinancialRecord(
        id: '1',
        type: FinancialRecordType.payment,
        description: 'Sessão',
        amount: 1000,
        date: DateTime(2026, 10, 1),
        category: 'PIX',
        status: 'PAGO',
      ),
      FinancialRecord(
        id: '2',
        type: FinancialRecordType.expense,
        description: 'DAS',
        amount: 80,
        date: DateTime(2026, 10, 2),
        category: 'IMPOSTOS',
        status: 'PAGO',
        dreClass: 'TAX',
      ),
      FinancialRecord(
        id: '3',
        type: FinancialRecordType.expense,
        description: 'Máquina',
        amount: 400,
        date: DateTime(2026, 10, 3),
        category: 'EQUIPAMENTOS',
        status: 'PAGO',
        dreClass: 'INVESTMENT',
      ),
    ];

    final dre = DreSummary.fromRecords(records, taxRate: 5);

    expect(dre.taxes, 80);
    expect(dre.taxesAreEstimated, isFalse);
    expect(dre.investments, 400);
    expect(dre.netResult, 920);
  });
}
