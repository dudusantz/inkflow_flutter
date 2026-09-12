import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:inkflow/core/data/supabase_providers.dart';
import 'package:inkflow/features/finance/domain/financial_record.dart';

class FinanceRepository {
  final SupabaseClient _supabase;

  const FinanceRepository(this._supabase);

  String get _artistId {
    final id = _supabase.auth.currentUser?.id;
    if (id == null) throw const AuthException('Sessão expirada.');
    return id;
  }

  Future<List<FinancialRecord>> listRecords() async {
    final results = await Future.wait([
      _supabase
          .from('payments')
          .select('id, appointment_id, description, amount, method, status, '
              'paid_at, created_at')
          .eq('artist_id', _artistId),
      _supabase
          .from('expenses')
          .select('id, description, amount, category, expense_date')
          .eq('artist_id', _artistId),
    ]);

    final records = <FinancialRecord>[
      ...results[0].map(
          (row) => FinancialRecord.payment(Map<String, dynamic>.from(row))),
      ...results[1].map(
          (row) => FinancialRecord.expense(Map<String, dynamic>.from(row))),
    ]..sort((a, b) => b.date.compareTo(a.date));
    return records;
  }

  Future<void> addPayment({
    required String description,
    required double amount,
    required String method,
    required String status,
    String? appointmentId,
  }) async {
    await _supabase.from('payments').insert({
      'artist_id': _artistId,
      'description': description,
      'amount': amount,
      'method': method,
      'status': status,
      'appointment_id': appointmentId,
      'paid_at': status == 'PAGO' ? DateTime.now().toIso8601String() : null,
    });
  }

  Future<void> addExpense({
    required String description,
    required double amount,
    required String category,
    required DateTime date,
  }) async {
    await _supabase.from('expenses').insert({
      'artist_id': _artistId,
      'description': description,
      'amount': amount,
      'category': category,
      'expense_date': DateFormat('yyyy-MM-dd').format(date),
    });
  }

  Future<void> deleteRecord(FinancialRecord record) async {
    final table =
        record.type == FinancialRecordType.payment ? 'payments' : 'expenses';
    await _supabase
        .from(table)
        .delete()
        .eq('id', record.id)
        .eq('artist_id', _artistId);
  }

  Future<Map<String, dynamic>?> getFiscalProfile() async {
    final row = await _supabase
        .from('artist_fiscal_profiles')
        .select()
        .eq('artist_id', _artistId)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<void> saveFiscalProfile(Map<String, dynamic> values) async {
    await _supabase.from('artist_fiscal_profiles').upsert({
      'artist_id': _artistId,
      ...values,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepository(ref.watch(supabaseClientProvider));
});

final financialRecordsProvider =
    FutureProvider.autoDispose<List<FinancialRecord>>((ref) {
  return ref.watch(financeRepositoryProvider).listRecords();
});
