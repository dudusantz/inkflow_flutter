enum FinancialRecordType { payment, expense }

class FinancialRecord {
  final String id;
  final FinancialRecordType type;
  final String description;
  final double amount;
  final DateTime date;
  final String category;
  final String status;
  final String? appointmentId;

  const FinancialRecord({
    required this.id,
    required this.type,
    required this.description,
    required this.amount,
    required this.date,
    required this.category,
    required this.status,
    this.appointmentId,
  });

  factory FinancialRecord.payment(Map<String, dynamic> row) => FinancialRecord(
        id: row['id'].toString(),
        type: FinancialRecordType.payment,
        description: row['description']?.toString() ?? 'Pagamento de sessão',
        amount: double.tryParse(row['amount']?.toString() ?? '') ?? 0,
        date: DateTime.tryParse(row['paid_at']?.toString() ??
                row['created_at']?.toString() ??
                '') ??
            DateTime.now(),
        category: row['method']?.toString() ?? 'OUTRO',
        status: row['status']?.toString() ?? 'PENDENTE',
        appointmentId: row['appointment_id']?.toString(),
      );

  factory FinancialRecord.expense(Map<String, dynamic> row) => FinancialRecord(
        id: row['id'].toString(),
        type: FinancialRecordType.expense,
        description: row['description']?.toString() ?? 'Despesa',
        amount: double.tryParse(row['amount']?.toString() ?? '') ?? 0,
        date: DateTime.tryParse(row['expense_date']?.toString() ?? '') ??
            DateTime.now(),
        category: row['category']?.toString() ?? 'OUTROS',
        status: 'PAGO',
      );
}

class FinancialSummary {
  final double received;
  final double pending;
  final double expenses;

  const FinancialSummary({
    required this.received,
    required this.pending,
    required this.expenses,
  });

  double get net => received - expenses;
}
