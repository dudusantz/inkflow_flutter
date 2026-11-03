import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:inkflow/features/schedule/domain/appointment.dart';

class AppointmentNotificationService {
  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  void Function(String route)? _onRoute;

  AppointmentNotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  bool get _isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  void setRouteHandler(void Function(String route) onRoute) {
    _onRoute = onRoute;
  }

  Future<void> initialize() async {
    if (!_isSupported || _initialized) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final route = response.payload;
        if (route != null && route.isNotEmpty) _onRoute?.call(route);
      },
    );
    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    if (!_isSupported) return false;
    await initialize();

    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          false;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true) ??
        false;
  }

  Future<void> sync(Iterable<Appointment> appointments) async {
    if (!_isSupported) return;
    await initialize();
    for (final appointment in appointments) {
      if (appointment.reminderEnabled) {
        await schedule(appointment);
      } else {
        await cancel(appointment.id);
      }
    }
  }

  Future<void> schedule(Appointment appointment, {DateTime? now}) async {
    if (!_isSupported) return;
    final reminder = appointmentReminderAt(appointment);
    if (reminder == null || !reminder.isAfter(now ?? DateTime.now())) {
      await cancel(appointment.id);
      return;
    }

    await initialize();
    await _plugin.zonedSchedule(
      id: notificationIdForAppointment(appointment.id),
      title: 'Sua sessão é amanhã',
      body: '${appointment.style} às ${appointment.startTime}.',
      scheduledDate: tz.TZDateTime.from(reminder.toUtc(), tz.UTC),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'appointment_reminders',
          'Lembretes de sessões',
          channelDescription: 'Avisos enviados 24 horas antes das sessões.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          threadIdentifier: 'appointment_reminders',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: '/schedule',
    );
  }

  Future<void> cancel(String appointmentId) async {
    if (!_isSupported) return;
    await initialize();
    await _plugin.cancel(id: notificationIdForAppointment(appointmentId));
  }
}

@visibleForTesting
DateTime? appointmentReminderAt(Appointment appointment) =>
    appointment.startsAt?.subtract(const Duration(hours: 24));

@visibleForTesting
int notificationIdForAppointment(String appointmentId) {
  var hash = 0x811c9dc5;
  for (final unit in appointmentId.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

final appointmentNotificationServiceProvider =
    Provider<AppointmentNotificationService>(
  (_) => AppointmentNotificationService(),
);
