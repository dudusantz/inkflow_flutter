import 'dart:typed_data';

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
    await _supabase.rpc('materialize_recurring_expenses');
    final results = await Future.wait([
      _supabase
          .from('payments')
          .select('id, appointment_id, description, amount, method, status, '
              'customer_name, customer_tax_id, customer_email, customer_phone, customer_address, '
              'paid_at, created_at, notes, receipt_path, appointments(client_name)')
          .eq('artist_id', _artistId),
      _supabase
          .from('expenses')
          .select('id, description, amount, category, expense_date, notes, '
              'dre_class, receipt_path, recurring_active, recurring_source_id')
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
    required String customerName,
    String? customerTaxId,
    String? customerEmail,
    String? customerPhone,
    String? customerAddress,
    String? appointmentId,
    String? notes,
    Uint8List? receiptBytes,
    String? receiptName,
    String? receiptMimeType,
  }) async {
    final row = await _supabase
        .from('payments')
        .insert({
          'artist_id': _artistId,
          'description': description,
          'amount': amount,
          'method': method,
          'status': status,
          'customer_name': customerName,
          'customer_tax_id': customerTaxId,
          'customer_email': customerEmail,
          'customer_phone': customerPhone,
          'customer_address': customerAddress,
          'notes': notes,
          'appointment_id': appointmentId,
          'paid_at': status == 'PAGO' ? DateTime.now().toIso8601String() : null,
        })
        .select('id')
        .single();
    if (receiptBytes != null && receiptName != null) {
      await _uploadReceipt(
        table: 'payments',
        id: row['id'].toString(),
        bytes: receiptBytes,
        name: receiptName,
        mimeType: receiptMimeType,
      );
    }
  }

  Future<void> addExpense({
    required String description,
    required double amount,
    required String category,
    required String dreClass,
    required DateTime date,
    String? notes,
    bool recurring = false,
    Uint8List? receiptBytes,
    String? receiptName,
    String? receiptMimeType,
  }) async {
    final month = DateTime(date.year, date.month, 1);
    final row = await _supabase
        .from('expenses')
        .insert({
          'artist_id': _artistId,
          'description': description,
          'amount': amount,
          'category': category,
          'dre_class': dreClass,
          'expense_date': DateFormat('yyyy-MM-dd').format(date),
          'notes': notes,
          'recurring_active': recurring,
          'recurrence_day': recurring ? date.day : null,
          'recurrence_last_generated':
              recurring ? DateFormat('yyyy-MM-dd').format(month) : null,
        })
        .select('id')
        .single();

    if (receiptBytes != null && receiptName != null) {
      await _uploadReceipt(
        table: 'expenses',
        id: row['id'].toString(),
        bytes: receiptBytes,
        name: receiptName,
        mimeType: receiptMimeType,
      );
    }
  }

  Future<void> _uploadReceipt({
    required String table,
    required String id,
    required Uint8List bytes,
    required String name,
    String? mimeType,
  }) async {
    final extension =
        name.contains('.') ? name.split('.').last.toLowerCase() : 'jpg';
    final path = '$_artistId/$table/$id/comprovante.$extension';
    try {
      await _supabase.storage.from('fiscal-documents').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: mimeType ?? 'image/jpeg',
              upsert: false,
            ),
          );
      await _supabase
          .from(table)
          .update({'receipt_path': path})
          .eq('id', id)
          .eq('artist_id', _artistId);
    } catch (_) {
      await _supabase
          .from(table)
          .delete()
          .eq('id', id)
          .eq('artist_id', _artistId);
      rethrow;
    }
  }

  Future<String> getRecordReceiptUrl(FinancialRecord record) async {
    if (record.receiptPath == null) {
      throw ArgumentError('A despesa não possui comprovante.');
    }
    return _supabase.storage
        .from('fiscal-documents')
        .createSignedUrl(record.receiptPath!, 60 * 10);
  }

  Future<void> stopRecurringExpense(String id) async {
    await _supabase
        .from('expenses')
        .update({'recurring_active': false})
        .eq('id', id)
        .eq('artist_id', _artistId);
  }

  Future<void> deleteRecord(FinancialRecord record) async {
    final table =
        record.type == FinancialRecordType.payment ? 'payments' : 'expenses';
    await _supabase
        .from(table)
        .delete()
        .eq('id', record.id)
        .eq('artist_id', _artistId);
    if (record.receiptPath != null) {
      try {
        await _supabase.storage
            .from('fiscal-documents')
            .remove([record.receiptPath!]);
      } catch (_) {
        // A movimentação já foi removida; um comprovante órfão não deve bloquear.
      }
    }
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
