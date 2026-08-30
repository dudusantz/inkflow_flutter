import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/schedule/domain/appointment.dart';

Map<String, dynamic> row({
  String? date = '2026-08-20',
  String? time = '09:00:00',
  String? endTime = '11:00:00',
  String? clientName = 'Carlos Mendes',
  Object? price = 600,
}) {
  return {
    'id': 'a1',
    'artist_id': 'artist-1',
    'client_id': 'client-1',
    'client_name': clientName,
    'date': date,
    'time': time,
    'end_time': endTime,
    'style': 'Geométrico',
    'price': price,
    'status': 'CONFIRMADO',
    'anamnesis_status': 'ok',
    'reminder_enabled': true,
  };
}

void main() {
  group('Appointment.tryFromRow', () {
    test('normaliza os horários vindos do Postgres', () {
      final appointment = Appointment.tryFromRow(row())!;

      expect(appointment.startTime, '09:00');
      expect(appointment.endTime, '11:00');
      expect(appointment.timeRangeLabel, '09:00 – 11:00');
    });

    test('descarta linha incompleta em vez de lançar', () {
      // Antes o código fazia `s['end_time'] as String` e derrubava a tela
      // inteira por causa de um único registro sem horário.
      expect(Appointment.tryFromRow(row(endTime: null)), isNull);
      expect(Appointment.tryFromRow(row(time: null)), isNull);
      expect(Appointment.tryFromRow(row(date: null)), isNull);
      expect(Appointment.tryFromRow(row(time: '9h')), isNull);
    });

    test('usa valores padrão para campos opcionais ausentes', () {
      final appointment =
          Appointment.tryFromRow(row(clientName: null, price: null))!;

      expect(appointment.clientName, 'Cliente');
      expect(appointment.price, 0);
    });

    test('isOn compara apenas o dia', () {
      final appointment = Appointment.tryFromRow(row())!;

      expect(appointment.isOn(DateTime(2026, 8, 20, 23, 59)), isTrue);
      expect(appointment.isOn(DateTime(2026, 8, 21)), isFalse);
    });

    test('slot permite detectar conflito com outra sessão', () {
      final first = Appointment.tryFromRow(row())!;
      final second = Appointment.tryFromRow(
        row(time: '10:00', endTime: '12:00'),
      )!;

      expect(first.slot!.overlaps(second.slot!), isTrue);
    });
  });
}
