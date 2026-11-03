import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:inkflow/core/errors/error_utils.dart';
import 'package:inkflow/core/theme/app_theme.dart';
import 'package:inkflow/core/widgets/shared_widgets.dart';
import 'package:inkflow/features/schedule/data/appointment_repository.dart';
import 'package:inkflow/features/schedule/domain/appointment.dart';
import 'package:inkflow/features/schedule/presentation/schedule_screen.dart';
import 'package:inkflow/features/schedule/services/appointment_notification_service.dart';

/// Sessões futuras marcadas (ou não) para receber lembrete.
final upcomingRemindersProvider =
    FutureProvider.autoDispose<List<Appointment>>((ref) async {
  final appointments = await ref.watch(scheduleProvider.future);
  final today = DateTime.now();
  final startOfToday = DateTime(today.year, today.month, today.day);

  return appointments.where((a) => !a.date.isBefore(startOfToday)).toList();
});

/// Lembretes de sessão (RF09).
///
/// A lista vem da agenda real e cada opção agenda ou cancela o aviso local.
class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    Appointment appointment,
  ) async {
    final enabled = !appointment.reminderEnabled;
    try {
      final notifications = ref.read(appointmentNotificationServiceProvider);
      if (enabled && !await notifications.requestPermissions()) {
        if (!context.mounted) return;
        showErrorSnackBar(
          context,
          'Ative as notificações do InkFlow nas configurações do aparelho.',
        );
        return;
      }
      await ref
          .read(appointmentRepositoryProvider)
          .setReminderEnabled(appointment.id, enabled);
      if (enabled) {
        await notifications.schedule(appointment);
      } else {
        await notifications.cancel(appointment.id);
      }
      ref.invalidate(scheduleProvider);
    } catch (e) {
      if (!context.mounted) return;
      showErrorSnackBar(context, userFriendlyErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(upcomingRemindersProvider);

    return Scaffold(
      backgroundColor: InkFlowColors.background,
      body: Column(
        children: [
          const AppHeader(
            title: 'Lembretes de Sessão',
            showBack: true,
            backTo: '/home',
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Row(
              children: [
                Icon(Icons.notifications_active_outlined,
                    size: 18, color: InkFlowColors.accentDark),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'O aviso é enviado neste aparelho 24 horas antes da sessão.',
                    style:
                        TextStyle(color: InkFlowColors.textMuted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: remindersAsync.when(
              loading: () => const Center(
                  child:
                      CircularProgressIndicator(color: InkFlowColors.accent)),
              error: (e, _) => AsyncErrorView(
                error: e,
                customMessage: 'Erro ao carregar os lembretes.',
                onRetry: () => ref.invalidate(scheduleProvider),
              ),
              data: (appointments) {
                if (appointments.isEmpty) {
                  return Center(
                    child: Text(
                      'Nenhuma sessão futura na agenda.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: appointments.length,
                  itemBuilder: (context, index) {
                    final appointment = appointments[index];
                    return _ReminderCard(
                      appointment: appointment,
                      onToggle: () => _toggle(context, ref, appointment),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback onToggle;

  const _ReminderCard({required this.appointment, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final enabled = appointment.reminderEnabled;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appointment.clientName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  '${appointment.style} — '
                  '${DateFormat('dd/MM/yyyy').format(appointment.date)} às '
                  '${appointment.startTime}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            activeThumbColor: InkFlowColors.accent,
            onChanged: (_) => onToggle(),
          ),
        ],
      ),
    );
  }
}
