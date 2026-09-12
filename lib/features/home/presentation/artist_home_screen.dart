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
      expectedRevenue: appointments.fold<double>(0, (sum, a) => sum + a.price),
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
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const InkFlowLogo(height: 36),
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.07),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                onPressed: () => context.go('/notifications'),
                                tooltip: 'Notificações',
                                icon: const Icon(Icons.notifications_none,
                                    color: Colors.white, size: 23),
                              ),
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
                    const SizedBox(height: 30),
                    Text(
                      'Olá, ${profile?.firstName ?? 'Tatuador'} 👋',
                      style: const TextStyle(
                        color: Color(0xFFA6A6AD),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _greeting(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formattedDate,
                      style: const TextStyle(
                          color: Color(0xFF8D8D95), fontSize: 13),
                    ),
                    const SizedBox(height: 22),
                    _buildRevenueCard(summary.expectedRevenue),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                            child: _buildMetricCard(
                          icon: Icons.calendar_today_outlined,
                          value: summary.totalSessions.toString(),
                          label: 'Sessões hoje',
                        )),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _buildMetricCard(
                          icon: Icons.assignment_outlined,
                          value: summary.pendingAnamnesis.toString(),
                          label: 'Anamneses pendentes',
                          valueColor: InkFlowColors.warning,
                        )),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  minHeight: MediaQuery.sizeOf(context).height * 0.55,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Acesso rápido',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF202A3A),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildManagementAction(
                        context,
                        onTap: () => context.go('/studio-management'),
                      ),
                      const SizedBox(height: 10),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 2.55,
                        children: [
                          _buildQuickAction(Icons.calendar_month_outlined,
                              'Agenda', () => context.go('/schedule')),
                          _buildQuickAction(Icons.chat_bubble_outline_rounded,
                              'Conversas', () => context.go('/inbox')),
                          _buildQuickAction(Icons.notifications_active_outlined,
                              'Lembretes', () => context.go('/reminders')),
                          _buildQuickAction(Icons.search_rounded, 'Buscar',
                              () => context.go('/search')),
                        ],
                      ),
                      const SizedBox(height: 26),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Agenda de hoje',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF202A3A))),
                          TextButton(
                            onPressed: () => context.go('/schedule'),
                            child: const Text('Ver agenda',
                                style: TextStyle(
                                    color: Color(0xFF167D7B),
                                    fontWeight: FontWeight.w700)),
                          )
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (appointments.isEmpty)
                        _buildEmptyAgenda(context)
                      else
                        ...appointments.map(
                          (appointment) =>
                              _AppointmentCard(appointment: appointment),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }

  Widget _buildRevenueCard(double revenue) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3537), Color(0xFF182426)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: InkFlowColors.accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: InkFlowColors.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.payments_outlined,
                color: InkFlowColors.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Faturamento previsto hoje',
                    style: TextStyle(color: Color(0xFFB5C0C1), fontSize: 12)),
                const SizedBox(height: 3),
                Text(
                  NumberFormat.currency(
                    locale: 'pt_BR',
                    symbol: 'R\$',
                    decimalDigits: 0,
                  ).format(revenue),
                  style: const TextStyle(
                    color: InkFlowColors.accent,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.trending_up_rounded,
              color: InkFlowColors.accent, size: 25),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String value,
    required String label,
    Color? valueColor,
  }) {
    return Semantics(
      label: '$label: $value',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F24),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF898995), size: 21),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: valueColor ?? Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: Color(0xFF96969E), fontSize: 10),
                  ),
                ],
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE6E9ED)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: InkFlowColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: const Color(0xFF167D7B), size: 19),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF303A4A),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManagementAction(
    BuildContext context, {
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF183638), Color(0xFF25494A)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: InkFlowColors.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.account_balance_wallet_outlined,
                    color: InkFlowColors.accent, size: 23),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gestão do estúdio',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Financeiro, fiscal e relatórios',
                      style: TextStyle(
                        color: Color(0xFFB8C9C9),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded,
                  color: InkFlowColors.accent, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyAgenda(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EAED)),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: InkFlowColors.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_available_outlined,
                color: Color(0xFF267F7D), size: 26),
          ),
          const SizedBox(height: 10),
          const Text('Seu dia está livre',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF202A3A))),
          const SizedBox(height: 5),
          const Text(
            'Você ainda não possui sessões agendadas para hoje.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF7C8491)),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => context.go('/schedule'),
            icon: const Icon(Icons.add_rounded, size: 19),
            label: const Text('Criar agendamento'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF167D7B),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
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
      'ok' => (const Color(0xFFDBEAFE), const Color(0xFF1D4ED8), 'Anamnese OK'),
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
