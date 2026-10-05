import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:inkflow/core/data/supabase_providers.dart';
import 'package:inkflow/features/schedule/domain/appointment.dart';

/// Sinaliza que o banco recusou a gravacao por sobreposicao de horario.
class AppointmentConflictException implements Exception {
  const AppointmentConflictException();
}

class ProposalAcceptanceException implements Exception {
  final String message;

  const ProposalAcceptanceException(this.message);
}

/// Codigo SQLSTATE de violacao de constraint de exclusao, disparado pela
/// constraint `appointments_no_overlap` da migration 002.
const _exclusionViolation = '23P01';

const _appointmentColumns =
    'id, artist_id, client_id, client_name, date, time, end_time, style, '
    'price, status, anamnesis_status, reminder_enabled';

class AppointmentRepository {
  final SupabaseClient _supabase;

  AppointmentRepository(this._supabase);

  String? get _myId => _supabase.auth.currentUser?.id;

  /// Agenda completa do usuario, no papel informado.
  Future<List<Appointment>> listForUser({required bool asArtist}) async {
    final myId = _myId;
    if (myId == null) return const [];

    final rows = await _supabase
        .from('appointments')
        .select(_appointmentColumns)
        .eq(asArtist ? 'artist_id' : 'client_id', myId)
        .order('date')
        .order('time');

    return _map(rows);
  }

  Future<List<Appointment>> listTodayForArtist() async {
    final myId = _myId;
    if (myId == null) return const [];

    final rows = await _supabase
        .from('appointments')
        .select(_appointmentColumns)
        .eq('artist_id', myId)
        .eq('date', DateFormat('yyyy-MM-dd').format(DateTime.now()))
        .order('time');

    return _map(rows);
  }

  /// Proxima sessao futura do cliente logado.
  Future<Appointment?> nextSessionForClient() async {
    final myId = _myId;
    if (myId == null) return null;

    final row = await _supabase
        .from('appointments')
        .select(_appointmentColumns)
        .eq('client_id', myId)
        .gte('date', DateFormat('yyyy-MM-dd').format(DateTime.now()))
        .order('date')
        .order('time')
        .limit(1)
        .maybeSingle();

    if (row == null) return null;
    return Appointment.tryFromRow(Map<String, dynamic>.from(row));
  }

  /// Cria a sessao. Lanca [AppointmentConflictException] se o banco detectar
  /// sobreposicao — a checagem no cliente nao protege contra duas gravacoes
  /// concorrentes.
  Future<void> create(NewAppointment appointment) async {
    final myId = _myId;
    if (myId == null) {
      throw const AuthException('Sessão expirada. Entre novamente.');
    }

    try {
      await _supabase.from('appointments').insert({
        'artist_id': myId,
        'client_name': appointment.clientName,
        'date': DateFormat('yyyy-MM-dd').format(appointment.date),
        'time': appointment.startTime,
        'end_time': appointment.endTime,
        'style': appointment.style,
        'reminder_enabled': true,
      });
    } on PostgrestException catch (e) {
      if (e.code == _exclusionViolation) {
        throw const AppointmentConflictException();
      }
      rethrow;
    }
  }

  Future<void> acceptProposalWithAnamnesis({
    required String proposalId,
    required Map<String, dynamic> answers,
    required String signatureName,
  }) async {
    try {
      await _supabase.rpc('accept_proposal_with_anamnesis', params: {
        'p_proposal_id': proposalId,
        'p_answers': answers,
        'p_signature_name': signatureName,
      });
    } on PostgrestException catch (error) {
      if (error.message.contains('APPOINTMENT_CONFLICT')) {
        throw const AppointmentConflictException();
      }
      final message = switch (error.message) {
        final text when text.contains('PROPOSAL_EXPIRED') =>
          'O horário desta proposta já passou.',
        final text when text.contains('PROPOSAL_UNAVAILABLE') =>
          'Esta proposta não está mais disponível.',
        final text when text.contains('PROPOSAL_NOT_FOUND') =>
          'Não foi possível localizar esta proposta.',
        _ => 'Não foi possível aceitar a proposta. Tente novamente.',
      };
      throw ProposalAcceptanceException(message);
    }
  }

  Future<void> setReminderEnabled(String appointmentId, bool enabled) async {
    await _supabase
        .from('appointments')
        .update({'reminder_enabled': enabled}).eq('id', appointmentId);
  }

  Future<SavedAnamnesis?> anamnesisForAppointment(String appointmentId) async {
    final row = await _supabase
        .from('appointment_anamneses')
        .select('answers, signature_name, has_risk, signed_at')
        .eq('appointment_id', appointmentId)
        .maybeSingle();
    if (row == null) return null;
    return SavedAnamnesis.tryFromRow(Map<String, dynamic>.from(row));
  }

  Future<SavedAnamnesis?> anamnesisForProposal(String proposalId) async {
    final appointment = await _supabase
        .from('appointments')
        .select('id')
        .eq('proposal_id', proposalId)
        .maybeSingle();
    if (appointment == null) return null;
    return anamnesisForAppointment(appointment['id'].toString());
  }

  /// Descarta linhas incompletas em vez de derrubar a tela inteira.
  List<Appointment> _map(List<dynamic> rows) {
    return rows
        .map((row) => Appointment.tryFromRow(Map<String, dynamic>.from(row)))
        .whereType<Appointment>()
        .toList();
  }
}

final appointmentRepositoryProvider = Provider<AppointmentRepository>((ref) {
  return AppointmentRepository(ref.watch(supabaseClientProvider));
});
