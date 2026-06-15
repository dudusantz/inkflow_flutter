import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

enum ScheduleScenario { sessions, conflict, empty }

const _sessions = [
  {'id': 1, 'time': '09:00', 'duration': '2h', 'client': 'Carlos Mendes', 'style': 'Geométrico', 'status': 'confirmed', 'anamnesis': 'ok'},
  {'id': 2, 'time': '12:00', 'duration': '3h', 'client': 'Fernanda Lima', 'style': 'Black Work', 'status': 'confirmed', 'anamnesis': 'pending'},
  {'id': 3, 'time': '16:30', 'duration': '1h30', 'client': 'Roberto Alves', 'style': 'Minimalista', 'status': 'confirmed', 'anamnesis': 'ok'},
];

const _weekDays = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  ScheduleScenario _scenario = ScheduleScenario.sessions;
  int _selectedDay = DateTime.now().weekday % 7;
  bool _showNewForm = false;
  bool _conflictError = false;
  bool _retrying = false;

  final _newSession = {'client': '', 'style': '', 'date': '', 'time': '', 'duration': '2h'};

  List<Map<String, dynamic>> get _currentSessions {
    return (_scenario == ScheduleScenario.sessions || _scenario == ScheduleScenario.conflict)
        ? List<Map<String, dynamic>>.from(_sessions)
        : [];
  }

  List<DateTime> _getWeekDays() {
    final today = DateTime.now();
    final start = today.subtract(Duration(days: today.weekday % 7));
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }

  void _applyScenario(ScheduleScenario s) {
    setState(() {
      _scenario = s;
      _showNewForm = false;
      _conflictError = false;
    });
  }

  void _handleSave() {
    if (_scenario == ScheduleScenario.conflict) {
      setState(() => _conflictError = true);
    } else {
      setState(() {
        _conflictError = false;
        _showNewForm = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agendamento adicionado com sucesso!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _handleRetry() async {
    setState(() => _retrying = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      setState(() {
        _retrying = false;
        _scenario = ScheduleScenario.sessions;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ScenarioSwitcher(
            rf: 'RF06/08',
            active: _scenario.name,
            scenarios: const [
              ScenarioConfig(key: 'sessions', label: '✓ Com Sessões', color: ScenarioColor.green),
              ScenarioConfig(key: 'conflict', label: '✗ Conflito', color: ScenarioColor.red),
              ScenarioConfig(key: 'empty', label: '⚠ Agenda Livre', color: ScenarioColor.yellow),
            ],
            onChange: (k) => _applyScenario(
                ScheduleScenario.values.firstWhere((e) => e.name == k)),
          ),

          AppHeader(
            title: 'Agenda',
            showBack: true,
            backTo: '/home',
            rightElement: GestureDetector(
              onTap: () => setState(() => _showNewForm = true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: InkFlowColors.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '+ Novo',
                  style: TextStyle(
                      color: InkFlowColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),

          // Semana
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              children: List.generate(7, (i) {
                final day = _getWeekDays()[i];
                final isSelected = i == _selectedDay;
                final isToday = day.day == DateTime.now().day;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedDay = i),
                    child: Column(
                      children: [
                        Text(
                          _weekDays[i],
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected
                                ? InkFlowColors.accent
                                : Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: isSelected ? InkFlowColors.primary : Colors.transparent,
                            shape: BoxShape.circle,
                            border: isToday && !isSelected
                                ? Border.all(color: InkFlowColors.accent, width: 1.5)
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              '${day.day}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: switch (_scenario) {
              ScheduleScenario.empty => _buildEmpty(),
              _ => _buildSessionList(),
            },
          ),

          if (_showNewForm) _buildNewSessionForm(),
          const BottomNav(currentIndex: 1),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: InkFlowColors.accent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.calendar_today,
                color: InkFlowColors.accent, size: 36),
          ),
          const SizedBox(height: 16),
          const Text('Dia livre!',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151))),
          const SizedBox(height: 8),
          Text(
            'Sem sessões agendadas para este dia.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => setState(() => _showNewForm = true),
            style: ElevatedButton.styleFrom(
              backgroundColor: InkFlowColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('+ Novo Agendamento Manual'),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionList() {
    final sessions = _currentSessions;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sessions.length,
      itemBuilder: (context, i) {
        final s = sessions[i];
        final isOk = s['anamnesis'] == 'ok';
        return GestureDetector(
          onTap: () => context.go('/reminders'),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hora
                Column(
                  children: [
                    Text(s['time'] as String,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: InkFlowColors.primary)),
                    Text(s['duration'] as String,
                        style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 10)),
                  ],
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 2,
                  height: 50,
                  color: InkFlowColors.accent.withOpacity(0.3),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(s['client'] as String,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14)),
                          ),
                          StatusBadge.anamnesis(isOk),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(s['style'] as String,
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Confirmada',
                            style: TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNewSessionForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        boxShadow: [
          BoxShadow(color: Color(0x1A000000), blurRadius: 16, offset: Offset(0, -4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('Novo Agendamento Manual',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const Spacer(),
              GestureDetector(
                  onTap: () => setState(() {
                        _showNewForm = false;
                        _conflictError = false;
                      }),
                  child: const Icon(Icons.close, size: 20)),
            ],
          ),
          const SizedBox(height: 12),

          // Cliente
          _lightField('Nome do cliente', (v) => _newSession['client'] = v),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _lightField('Horário (ex: 14:00)',
                    (v) => _newSession['time'] = v),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _lightField('Estilo', (v) => _newSession['style'] = v),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Conflito
          if (_conflictError)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFFEF4444).withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Color(0xFFEF4444), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Existe um conflito de horário com uma sessão já agendada',
                      style: TextStyle(
                          color: Color(0xFFEF4444), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: InkFlowColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Salvar Agendamento',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lightField(String hint, ValueChanged<String> onChanged) {
    return TextFormField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      ),
    );
  }
}
