import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:inkflow/core/errors/error_utils.dart';
import 'package:inkflow/core/theme/app_theme.dart';
import 'package:inkflow/core/widgets/shared_widgets.dart';
import 'package:inkflow/features/profile/domain/user_profile.dart';
import 'package:inkflow/features/profile/providers/profile_provider.dart';
import 'package:inkflow/features/schedule/data/appointment_repository.dart';
import 'package:inkflow/features/schedule/domain/appointment.dart';

final todayAppointmentsProvider =
    FutureProvider.autoDispose<List<Appointment>>((ref) {
  return ref.watch(appointmentRepositoryProvider).listTodayForArtist();
});

/// Resumo do dia exibido nos cartões de métrica.
class DailySummary {
  final int totalSessions;
  final double expectedRevenue;
  final int pendingAnamnesis;

  const DailySummary({
    required this.totalSessions,
    required this.expectedRevenue,
    required this.pendingAnamnesis,
  });

  factory DailySummary.from(List<Appointment> appointments) {
    return DailySummary(
      totalSessions: appointments.length,
      expectedRevenue:
          appointments.fold<double>(0, (sum, a) => sum + a.price),
      pendingAnamnesis:
          appointments.where((a) => a.anamnesisStatus == 'pendente').length,
    );
  }
}

class ArtistHomeScreen extends ConsumerWidget {
  const ArtistHomeScreen({super.key});

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bom dia!';
    if (hour < 18) return 'Boa tarde!';
    return 'Boa noite!';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final appointmentsAsync = ref.watch(todayAppointmentsProvider);

    return appointmentsAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF111116),
        body: Center(
          child: CircularProgressIndicator(color: InkFlowColors.accent),
        ),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: const Color(0xFF111116),
        body: AsyncErrorView(
          error: error,
          customMessage: 'Erro ao carregar agenda de hoje.',
          onRetry: () => ref.invalidate(todayAppointmentsProvider),
        ),
      ),
      data: (appointments) => _buildContent(
        context,
        profileAsync.value,
        appointments,
        DailySummary.from(appointments),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    UserProfile? profile,
    List<Appointment> appointments,
    DailySummary summary,
  ) {
    final formattedDate =
        DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFF111116),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const InkFlowLogo(height: 36),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => context.go('/notifications'),
                            tooltip: 'Notificações',
                            icon: const Icon(Icons.notifications_none,
                                color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 8),
                          Semantics(
                            button: true,
                            label: 'Abrir meu perfil',
                            child: GestureDetector(
                              onTap: () => context.go('/profile'),
                              child: AvatarImage(
                                url: profile?.avatarUrl,
                                size: 36,
                              ),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Olá, ${profile?.firstName ?? 'Tatuador'}',
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _greeting(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formattedDate,
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                          child: _buildMetricCard(
                              summary.totalSessions.toString(), 'Sessões hoje',
                              isHighlight: false)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _buildMetricCard(
                              'R\$ ${summary.expectedRevenue.toStringAsFixed(0)}',
                              'Previsto hoje',
                              isHighlight: true)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _buildMetricCard(
                              summary.pendingAnamnesis.toString(),
                              'Anamnese pendente',
                              isHighlight: false,
                              valueColor: InkFlowColors.warning)),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 20.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildQuickAction(Icons.search, 'Buscar',
                              () => context.go('/search')),
                          _buildQuickAction(Icons.calendar_today, 'Agenda',
                              () => context.go('/schedule')),
                          _buildQuickAction(Icons.chat_bubble_outline, 'Chat',
                              () => context.go('/inbox')),
                          _buildQuickAction(
                              Icons.notifications_active_outlined,
                              'Lembretes',
                              () => context.go('/reminders')),
                          _buildQuickAction(Icons.bar_chart, 'Dashboard',
                              () => context.go('/dashboard')),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Agenda de Hoje',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937))),
                          TextButton(
                            onPressed: () => context.go('/schedule'),
                            child: const Text('Ver tudo',
                                style: TextStyle(
                                    color: InkFlowColors.primary,
                                    fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                    ),
                    Expanded(
                      child: appointments.isEmpty
                          ? Center(
                              child: Text(
                                'Nenhuma sessão agendada para hoje.',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24.0, vertical: 8.0),
                              itemCount: appointments.length,
                              itemBuilder: (context, index) =>
                                  _AppointmentCard(
                                      appointment: appointments[index]),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }

  Widget _buildMetricCard(String value, String label,
      {required bool isHighlight, Color? valueColor}) {
    return Semantics(
      label: '$label: $value',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F24),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  color: valueColor ??
                      (isHighlight ? InkFlowColors.success : Colors.white),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF6B7280), size: 28),
            const SizedBox(height: 8),
            Text(label,
                style:
                    const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final Appointment appointment;

  const _AppointmentCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final (badgeColor, badgeTextColor, badgeText) =
        switch (appointment.anamnesisStatus) {
      'ok' => (
          const Color(0xFFDBEAFE),
          const Color(0xFF1D4ED8),
          'Anamnese OK'
        ),
      'risco' => (
          const Color(0xFFFEE2E2),
          const Color(0xFFB91C1C),
          'Condição de Risco'
        ),
      _ => (const Color(0xFFFEF3C7), const Color(0xFFB45309), 'Pendente'),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ]),
      child: Row(
        children: [
          Column(
            children: [
              Text(appointment.startTime,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      color: InkFlowColors.primary, shape: BoxShape.circle)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(appointment.clientName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF1F2937))),
                Text(appointment.style,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF6B7280))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: badgeColor, borderRadius: BorderRadius.circular(12)),
            child: Text(badgeText,
                style: TextStyle(
                    color: badgeTextColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}
