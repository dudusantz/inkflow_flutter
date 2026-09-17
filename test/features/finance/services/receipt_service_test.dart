import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/finance/domain/financial_record.dart';
import 'package:inkflow/features/finance/services/receipt_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('gera documento de serviço em PDF', () async {
    final bytes = await ReceiptService.buildReceipt(
      payment: FinancialRecord(
        id: '12345678-1234-1234-1234-123456789012',
        type: FinancialRecordType.payment,
        description: 'Sessão de tatuagem',
        amount: 500,
        date: DateTime(2026, 9, 16, 14, 30),
        category: 'PIX',
        status: 'PAGO',
        clientName: 'Cliente Teste',
      ),
      fiscalProfile: {
        'trade_name': 'Ink Studio',
        'legal_name': 'Ink Studio LTDA',
        'tax_id': '00.000.000/0001-00',
        'municipal_registration': '12345',
        'fiscal_address': 'Avenida Paulista, 1000, conjunto 101',
        'city': 'São Paulo',
        'state': 'SP',
        'postal_code': '01310-100',
        'email': 'contato@inkstudio.com.br',
        'phone': '(11) 99999-9999',
        'tax_rate': 5,
        'receipt_notes': List.filled(
          20,
          'Atendimento realizado conforme agendamento.',
        ).join(' '),
      },
    );

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
