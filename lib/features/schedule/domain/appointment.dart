import 'package:inkflow/core/utils/time_slot.dart';

/// Uma sessao agendada.
///
/// `startTime`/`endTime` sao sempre normalizados para `HH:mm`: o Postgres
/// devolve `time` como `HH:mm:ss` e o formulario aceita entrada livre.
class Appointment {
  final String id;
  final String artistId;
  final String? clientId;
  final String clientName;
  final DateTime date;
  final String startTime;
  final String endTime;
  final String style;
  final double price;
  final String status;
  final String anamnesisStatus;
  final bool reminderEnabled;

  const Appointment({
    required this.id,
    required this.artistId,
    required this.clientName,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.style,
    required this.price,
    required this.status,
    required this.anamnesisStatus,
    required this.reminderEnabled,
    this.clientId,
  });

  /// Retorna `null` para linhas sem data ou horario utilizavel, em vez de
  /// lancar. Antes o codigo fazia `s['end_time'] as String` e derrubava a tela
  /// inteira por causa de um unico registro incompleto.
  static Appointment? tryFromRow(Map<String, dynamic> row) {
    final date = DateTime.tryParse(row['date']?.toString() ?? '');
    final start = TimeSlot.normalize(row['time']?.toString());
    final end = TimeSlot.normalize(row['end_time']?.toString());
    if (date == null || start == null || end == null) return null;

    return Appointment(
      id: row['id'].toString(),
      artistId: row['artist_id']?.toString() ?? '',
      clientId: row['client_id']?.toString(),
      clientName: _nonEmpty(row['client_name']) ?? 'Cliente',
      date: DateTime(date.year, date.month, date.day),
      startTime: start,
      endTime: end,
      style: _nonEmpty(row['style']) ?? 'Indefinido',
      price: double.tryParse(row['price']?.toString() ?? '') ?? 0,
      status: _nonEmpty(row['status']) ?? 'Confirmado',
      anamnesisStatus: _nonEmpty(row['anamnesis_status']) ?? 'pendente',
      reminderEnabled: row['reminder_enabled'] as bool? ?? true,
    );
  }

  TimeSlot? get slot => TimeSlot.tryParse(startTime, endTime);

  String get timeRangeLabel => '$startTime – $endTime';

  bool isOn(DateTime day) =>
      date.year == day.year && date.month == day.month && date.day == day.day;

  static String? _nonEmpty(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}

/// Dados de criacao de uma sessao. Separado de [Appointment] porque o id, o
/// status e os defaults sao definidos pelo banco.
class NewAppointment {
  final String clientName;
  final DateTime date;
  final String startTime;
  final String endTime;
  final String style;

  const NewAppointment({
    required this.clientName,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.style,
  });
}
