import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

enum HomeScenario { loaded, error, empty }

const _sessions = [
  {
    'id': 1,
    'time': '09:00',
    'client': 'Carlos Mendes',
    'style': 'Geométrico',
    'anamnesis': 'ok',
    'avatar': 'https://images.unsplash.com/photo-1544604725-0ffa9861dec2?w=80&h=80&fit=crop&crop=face',
  },
  {
    'id': 2,
    'time': '12:00',
    'client': 'Fernanda Lima',
    'style': 'Black Work',
    'anamnesis': 'pending',
    'avatar': 'https://images.unsplash.com/photo-1612271974453-15e684c6586b?w=80&h=80&fit=crop&crop=face',
  },
  {
    'id': 3,
    'time': '16:30',
    'client': 'Roberto Alves',
    'style': 'Minimalista',
    'anamnesis': 'ok',
    'avatar': 'https://images.unsplash.com/photo-1544604725-0ffa9861dec2?w=80&h=80&fit=crop&crop=face',
  },
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeScenario _scenario = HomeScenario.loaded;
  bool _retrying = false;

  String get _today {
    return DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(DateTime.now());
  }

  Future<void> _handleRetry() async {
    setState(() => _retrying = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      setState(() {
        _retrying = false;
        _scenario = HomeScenario.loaded;
      });
    }
  }

  final _quickMenu = const [
    {'icon': Icons.search, 'label': 'Buscar', 'path': '/search'},
    {'icon': Icons.calendar_today, 'label': 'Agenda', 'path': '/schedule'},
    {'icon': Icons.chat_bubble, 'label': 'Chat', 'path': '/chat'},
    {'icon': Icons.notifications, 'label': 'Lembretes', 'path': '/reminders'},
    {'icon': Icons.bar_chart, 'label': 'Dashboard', 'path': '/dashboard'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ScenarioSwitcher(
            rf: 'RF08',
            active: _scenario.name,
            scenarios: const [
              ScenarioConfig(key: 'loaded', label: '✓ Com Sessões', color: ScenarioColor.green),
              ScenarioConfig(key: 'error', label: '✗ Falha de Conexão', color: ScenarioColor.red),
              ScenarioConfig(key: 'empty', label: '⚠ Agenda Livre', color: ScenarioColor.yellow),
            ],
            onChange: (k) => setState(() =>
                _scenario = HomeScenario.values.firstWhere((e) => e.name == k)),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  _buildHeader(),
                  _buildQuickNav(),
                  Expanded(child: _buildBody()),
                  const BottomNav(currentIndex: 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: InkFlowColors.primary,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo + ícones
          Row(
            children: [
              Image.asset('assets/inkflow_logo.png', height: 28),
              const Spacer(),
              Stack(
                children: [
                  Icon(Icons.notifications_outlined,
                      color: Colors.white.withOpacity(0.6), size: 22),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: Color(0xFFEF4444), shape: BoxShape.circle),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              AvatarImage(
                url: 'https://images.unsplash.com/photo-1612271974453-15e684c6586b?w=80&h=80&fit=crop&crop=face',
                size: 32,
                borderWidth: 2,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Olá, Ana 👋',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
          const Text('Bom dia!',
              style: TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(_today,
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),

          if (_scenario == HomeScenario.loaded) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                _statCard(_sessions.length.toString(), 'Sessões hoje'),
                const SizedBox(width: 8),
                _statCard('R\$ 1.800', 'Previsto hoje'),
                const SizedBox(width: 8),
                _statCard('1', 'Anamnese pendente', isWarning: true),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statCard(String value, String label, {bool isWarning = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: isWarning ? const Color(0xFFFBBF24) : InkFlowColors.accent,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickNav() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: _quickMenu.map((item) {
          return Expanded(
            child: GestureDetector(
              onTap: () => context.go(item['path'] as String),
              child: Column(
                children: [
                  Icon(item['icon'] as IconData,
                      color: Colors.grey.shade600, size: 22),
                  const SizedBox(height: 4),
                  Text(
                    item['label'] as String,
                    style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 10,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody() {
    return Container(
      color: InkFlowColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: switch (_scenario) {
          HomeScenario.error => _buildError(),
          HomeScenario.empty => _buildEmpty(),
          HomeScenario.loaded => _buildSessions(),
        },
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline,
                  color: Color(0xFFEF4444), size: 32),
            ),
            const SizedBox(height: 16),
            const Text('Não foi possível carregar sua agenda',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151))),
            const SizedBox(height: 8),
            Text(
              'Verifique sua conexão e tente novamente.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _retrying ? null : _handleRetry,
              icon: _retrying
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const SizedBox(),
              label: Text(_retrying ? 'Carregando...' : 'Tentar novamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: InkFlowColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: InkFlowColors.accent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Text('🌟', style: TextStyle(fontSize: 36),
                  textAlign: TextAlign.center),
            ),
            const SizedBox(height: 16),
            const Text('Sua agenda está livre hoje',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151))),
            const SizedBox(height: 8),
            Text(
              'Aproveite para descansar ou adicionar novos agendamentos.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => context.go('/schedule'),
              style: ElevatedButton.styleFrom(
                backgroundColor: InkFlowColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('+ Novo Agendamento'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Agenda de Hoje',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937))),
            GestureDetector(
              onTap: () => context.go('/schedule'),
              child: const Text('Ver tudo →',
                  style: TextStyle(
                      color: InkFlowColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._sessions.map((s) => _sessionCard(s)),
      ],
    );
  }

  Widget _sessionCard(Map<String, dynamic> s) {
    final isOk = s['anamnesis'] == 'ok';
    return GestureDetector(
      onTap: () => context.go('/anamnesis'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Column(
                children: [
                  Text(s['time'] as String,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: InkFlowColors.primary)),
                  const SizedBox(height: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        color: InkFlowColors.accent, shape: BoxShape.circle),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AvatarImage(url: s['avatar'] as String, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s['client'] as String,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827))),
                  Text(s['style'] as String,
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
            StatusBadge.anamnesis(isOk),
          ],
        ),
      ),
    );
  }
}
