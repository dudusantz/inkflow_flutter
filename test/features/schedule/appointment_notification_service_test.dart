import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/schedule/domain/appointment.dart';
import 'package:inkflow/features/schedule/services/appointment_notification_service.dart';

Appointment appointment() => Appointment(
      id: '0f73b821-55e1-46e4-a4dd-8db6355da618',
      artistId: 'artist-1',
      clientName: 'Carlos',
      date: DateTime(2026, 11, 5),
      startTime: '14:30',
      endTime: '16:00',
      style: 'Fineline',
      price: 500,
      status: 'CONFIRMADO',
      anamnesisStatus: 'ok',
      reminderEnabled: true,
    );

void main() {
  test('agenda o lembrete exatamente 24 horas antes da sessão', () {
    expect(
      appointmentReminderAt(appointment()),
      DateTime(2026, 11, 4, 14, 30),
    );
  });

  test('gera identificador estável e positivo para cancelar o lembrete', () {
    final first = notificationIdForAppointment(appointment().id);
    final second = notificationIdForAppointment(appointment().id);

    expect(first, second);
    expect(first, greaterThanOrEqualTo(0));
  });
}
