import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:inkflow/core/errors/error_utils.dart';
import 'package:inkflow/core/theme/app_theme.dart';
import 'package:inkflow/core/widgets/shared_widgets.dart';
import 'package:inkflow/features/schedule/data/appointment_repository.dart';
import 'package:inkflow/features/schedule/domain/appointment.dart';
import 'package:inkflow/features/schedule/presentation/schedule_screen.dart';

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
/// A tela anterior exibia três clientes fixos no código e um seletor de
/// cenários de protótipo. Aqui a lista vem da agenda real; o que continua
/// pendente é o disparo automático (24h antes), que depende de uma função
/// agendada no servidor.
class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    Appointment appointment,
  ) async {
    try {
      await ref
          .read(appointmentRepositoryProvider)
          .setReminderEnabled(appointment.id, !appointment.reminderEnabled);
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
          const UnderDevelopmentBanner(
            message: 'O disparo automático 24h antes ainda não está ativo. '
                'Aqui você define quais sessões devem recebê-lo.',
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
