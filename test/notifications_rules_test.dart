import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/profile/presentation/notifications_screen.dart';
import 'package:inkflow/features/schedule/domain/appointment.dart';

Appointment appointmentAt(String time, {String clientName = 'Carlos'}) {
  return Appointment.tryFromRow({
    'id': 'a-$time',
    'artist_id': 'artist-1',
    'client_name': clientName,
    'date': '2026-08-20',
    'time': time,
    'end_time': '23:59',
    'style': 'Geométrico',
    'price': 0,
    'status': 'CONFIRMADO',
    'anamnesis_status': 'ok',
    'reminder_enabled': true,
  })!;
}

void main() {
  group('buildNotifications', () {
    test('sempre gera o aviso de sessão agendada', () {
      final notifications = buildNotifications(
        [appointmentAt('15:00')],
        now: DateTime(2026, 8, 20, 9),
      );

      expect(
        notifications.where((n) => n.kind == NotificationKind.newBooking),
        hasLength(1),
      );
    });

    test('avisa quando faltam 30 minutos ou menos', () {
      final notifications = buildNotifications(
        [appointmentAt('09:25')],
        now: DateTime(2026, 8, 20, 9),
      );

      expect(
        notifications.any((n) => n.kind == NotificationKind.startingSoon),
        isTrue,
      );
    });

    test('não avisa quando ainda falta mais de 30 minutos', () {
      final notifications = buildNotifications(
        [appointmentAt('15:00')],
        now: DateTime(2026, 8, 20, 9),
      );

      expect(
        notifications.any((n) => n.kind == NotificationKind.startingSoon),
        isFalse,
      );
    });

    test('avisa que a sessão começou até 2h depois do horário', () {
      final started = buildNotifications(
        [appointmentAt('09:00')],
        now: DateTime(2026, 8, 20, 10),
      );
      final old = buildNotifications(
        [appointmentAt('09:00')],
        now: DateTime(2026, 8, 20, 14),
      );

      expect(
        started.any((n) => n.kind == NotificationKind.startingNow),
        isTrue,
      );
      expect(old.any((n) => n.kind == NotificationKind.startingNow), isFalse);
    });

    test('ordena do mais recente para o mais antigo', () {
      final notifications = buildNotifications(
        [appointmentAt('09:00'), appointmentAt('18:00')],
        now: DateTime(2026, 8, 20, 12),
      );

      for (var i = 1; i < notifications.length; i++) {
        expect(
          notifications[i - 1].createdAt.isBefore(notifications[i].createdAt),
          isFalse,
        );
      }
    });
  });
}
