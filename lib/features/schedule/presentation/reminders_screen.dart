import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inkflow/core/theme/app_theme.dart';
import 'package:inkflow/core/widgets/shared_widgets.dart';

enum RemindersScenario { sent, noConsent }

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  RemindersScenario _scenario = RemindersScenario.sent;

  final _reminders = [
    {
      'id': 1,
      'client': 'Carlos Mendes',
      'session': 'Geométrico — 20/08/2026 às 09:00',
      'type': 'whatsapp',
      'status': 'sent',
      'consent': true,
      'avatar':
          'https://images.unsplash.com/photo-1544604725-0ffa9861dec2?w=80&h=80&fit=crop&crop=face',
    },
    {
      'id': 2,
      'client': 'Fernanda Lima',
      'session': 'Black Work — 20/08/2026 às 12:00',
      'type': 'email',
      'status': 'sent',
      'consent': true,
      'avatar':
          'https://images.unsplash.com/photo-1612271974453-15e684c6586b?w=80&h=80&fit=crop&crop=face',
    },
    {
      'id': 3,
      'client': 'Roberto Alves',
      'session': 'Minimalista — 20/08/2026 às 16:30',
      'type': 'whatsapp',
      'status': 'blocked',
      'consent': false,
      'avatar':
          'https://images.unsplash.com/photo-1544604725-0ffa9861dec2?w=80&h=80&fit=crop&crop=face',
    },
  ];

  void _applyScenario(RemindersScenario s) {
    setState(() => _scenario = s);
  }

  List<Map<String, dynamic>> get _displayed {
    if (_scenario == RemindersScenario.noConsent) {
      return _reminders
          .where((r) => !(r['consent'] as bool))
          .toList()
          .cast<Map<String, dynamic>>();
    }
    return List<Map<String, dynamic>>.from(_reminders);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ScenarioSwitcher(
            rf: 'RF09',
            active: _scenario.name,
            scenarios: const [
              ScenarioConfig(
                  key: 'sent', label: '✓ Enviados', color: ScenarioColor.green),
              ScenarioConfig(
                  key: 'noConsent',
                  label: '✗ Sem Consentimento',
                  color: ScenarioColor.red),
            ],
            onChange: (k) => _applyScenario(
                RemindersScenario.values.firstWhere((e) => e.name == k)),
          ),

          AppHeader(
            title: 'Lembretes de Sessão',
            showBack: true,
            backTo: '/home',
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: InkFlowColors.accent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: InkFlowColors.accent.withOpacity(0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.notifications_active,
                            color: InkFlowColors.accent, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Lembretes são enviados 24h antes da sessão. Apenas para clientes com consentimento LGPD.',
                            style: TextStyle(
                                color: InkFlowColors.accent, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Sem consentimento warning
                  if (_scenario == RemindersScenario.noConsent)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFEF4444).withOpacity(0.3)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🔒 Lembrete Bloqueado — LGPD',
                            style: TextStyle(
                                color: Color(0xFFB91C1C),
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Roberto Alves não autorizou o recebimento de comunicações. O lembrete não foi enviado para proteger seus dados.',
                            style: TextStyle(
                                color: Color(0xFFDC2626), fontSize: 12),
                          ),
                        ],
                      ),
                    ),

                  // Lista
                  ..._displayed.map((r) => _reminderCard(r)),
                ],
              ),
            ),
          ),
          const BottomNav(currentIndex: 0),
        ],
      ),
    );
  }

  Widget _reminderCard(Map<String, dynamic> r) {
    final sent = r['status'] == 'sent' && (r['consent'] as bool);
    final typeIcon =
        r['type'] == 'whatsapp' ? Icons.chat_bubble : Icons.email;
    final typeLabel = r['type'] == 'whatsapp' ? 'WhatsApp' : 'E-mail';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: !sent
            ? Border.all(color: const Color(0xFFEF4444).withOpacity(0.3))
            : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarImage(url: r['avatar'] as String, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r['client'] as String,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(r['session'] as String,
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 11)),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: sent
                      ? const Color(0xFF10B981).withOpacity(0.1)
                      : const Color(0xFFEF4444).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  sent ? 'Enviado' : 'Bloqueado',
                  style: TextStyle(
                      color:
                          sent ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(typeIcon,
                  size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text(typeLabel,
                  style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 11)),
              const SizedBox(width: 12),
              Icon(Icons.lock_outline,
                  size: 13,
                  color: (r['consent'] as bool)
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444)),
              const SizedBox(width: 4),
              Text(
                (r['consent'] as bool) ? 'LGPD OK' : 'Sem consentimento',
                style: TextStyle(
                    color: (r['consent'] as bool)
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    fontSize: 11,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
