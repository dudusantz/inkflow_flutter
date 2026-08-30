/// Utilitarios de horario no formato `HH:mm`.
///
/// A agenda recebe horarios digitados livremente e os compara para detectar
/// conflito. Concentrar parsing e sobreposicao aqui evita que uma entrada
/// invalida (ex.: "9h") seja convertida silenciosamente em zero.
class TimeSlot {
  final int startMinutes;
  final int endMinutes;

  const TimeSlot._(this.startMinutes, this.endMinutes);

  /// Retorna `null` se qualquer um dos horarios for invalido ou se o fim nao
  /// vier depois do inicio.
  static TimeSlot? tryParse(String start, String end) {
    final s = parseMinutes(start);
    final e = parseMinutes(end);
    if (s == null || e == null || e <= s) return null;
    return TimeSlot._(s, e);
  }

  bool overlaps(TimeSlot other) =>
      startMinutes < other.endMinutes && other.startMinutes < endMinutes;

  /// Converte `HH:mm` (ou `HH:mm:ss`, como o Postgres devolve para `time`) em
  /// minutos desde a meia-noite. Devolve `null` para qualquer outro formato.
  static int? parseMinutes(String? value) {
    if (value == null) return null;
    final match = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$').firstMatch(value.trim());
    if (match == null) return null;

    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour > 23 || minute > 59) return null;

    return hour * 60 + minute;
  }

  /// Normaliza para `HH:mm`, descartando os segundos que vem do banco.
  /// Devolve `null` quando o valor nao e um horario reconhecivel.
  static String? normalize(String? value) {
    final minutes = parseMinutes(value);
    if (minutes == null) return null;
    final hour = (minutes ~/ 60).toString().padLeft(2, '0');
    final minute = (minutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
