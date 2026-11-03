import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/foundation.dart';

import 'package:inkflow/features/schedule/domain/appointment.dart';

class AppointmentCalendarService {
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<bool> add(Appointment appointment) async {
    final start = appointment.startsAt;
    final end = appointment.endsAt;
    if (!isSupported || start == null || end == null) return false;

    return Add2Calendar.addEvent2Cal(
      Event(
        title: 'Sessão de tatuagem — ${appointment.style}',
        description: 'Agendamento confirmado pelo InkFlow.',
        startDate: start,
        endDate: end,
        iosParams: const IOSParams(reminder: Duration(hours: 24)),
      ),
    );
  }
}
