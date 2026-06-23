import 'package:flutter/material.dart';
import 'package:inkflow/core/theme/app_theme.dart';
import 'package:inkflow/core/widgets/shared_widgets.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _showNewForm = false;
  String? _conflictError;
  int _selectedDay = DateTime.now().weekday % 7;

  final List<Map<String, dynamic>> _sessions = [
    {
      'time': '09:00',
      'endTime': '11:00',
      'date': 'Ter',
      'client': 'Carlos Mendes',
      'style': 'Geométrico',
      'duration': '2h',
      'reminderEnabled': true,
    },
    {
      'time': '14:00',
      'endTime': '17:00',
      'date': 'Qua',
      'client': 'Fernanda Lima',
      'style': 'Black Work',
      'duration': '3h',
      'reminderEnabled': true,
    },
  ];

  String _newClient = '';
  String _newStartTime = '';
  String _newEndTime = '';
  String _newStyle = '';
  final List<String> _weekDays = [
    'Dom',
    'Seg',
    'Ter',
    'Qua',
    'Qui',
    'Sex',
    'Sáb'
  ];

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  bool _hasOverlap(String startA, String endA, String startB, String endB) {
    final a1 = _timeToMinutes(startA);
    final a2 = _timeToMinutes(endA);
    final b1 = _timeToMinutes(startB);
    final b2 = _timeToMinutes(endB);
    return a1 < b2 && b1 < a2;
  }

  void _handleSave() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final day = _weekDays[_selectedDay];
      final hasConflict = _sessions.any((s) {
        if (s['date'] != day) return false;
        return _hasOverlap(
          _newStartTime,
          _newEndTime,
          s['time'] as String,
          s['endTime'] as String,
        );
      });

      if (hasConflict) {
        setState(() => _conflictError =
            'Existe um conflito de horário com uma sessão já agendada');
        return;
      }

      setState(() {
        _sessions.add({
          'time': _newStartTime,
          'endTime': _newEndTime,
          'date': _weekDays[_selectedDay],
          'client': _newClient,
          'style': _newStyle,
          'duration': '—',
          'reminderEnabled': true,
        });
        _sessions.sort((a, b) => a['time'].compareTo(b['time']));
        _showNewForm = false;
        _conflictError = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agendamento salvo!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  void _openSessionDetails(Map<String, dynamic> session) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session['client'] as String,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    '${session['date']} • ${session['time']} – ${session['endTime']}',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  Text('${session['style']}',
                      style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(height: 20),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Enviar lembrete automático de 24h',
                      style: TextStyle(fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Desative para cancelar o envio do lembrete desta sessão.',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: session['reminderEnabled'] as bool,
                    activeColor: InkFlowColors.accent,
                    onChanged: (v) {
                      setModalState(() => session['reminderEnabled'] = v);
                      setState(() => session['reminderEnabled'] = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: InkFlowColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Fechar'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final daySessions =
        _sessions.where((s) => s['date'] == _weekDays[_selectedDay]).toList();

    return Scaffold(
      body: Column(
        children: [
          AppHeader(
            title: 'Agenda',
            showBack: true,
            backTo: '/home',
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(7, (i) {
                final isSelected = i == _selectedDay;
                return GestureDetector(
                  onTap: () => setState(() => _selectedDay = i),
                  child: CircleAvatar(
                    backgroundColor:
                        isSelected ? InkFlowColors.primary : Colors.transparent,
                    radius: 20,
                    child: Text(
                      _weekDays[i],
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.white : Colors.grey.shade600,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: daySessions.isEmpty
                ? const Center(child: Text('Nenhuma sessão neste dia.'))
                : ListView.builder(
                    itemCount: daySessions.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, i) {
                      final s = daySessions[i];
                      return Card(
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          child: ListTile(
                          onTap: () => _openSessionDetails(s),
                          leading: Text(
                            s['time'] as String,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          title: Text(s['client'] as String),
                          subtitle: Text(
                            '${s['style']} • ${s['time']} – ${s['endTime']}',
                          ),
                          trailing: Icon(
                            (s['reminderEnabled'] as bool)
                                ? Icons.notifications_active
                                : Icons.notifications_off,
                            color: (s['reminderEnabled'] as bool)
                                ? InkFlowColors.accent
                                : Colors.grey,
                            size: 20,
                          ),
                        ),
                        ),
                      );
                    },
                  ),
          ),
          if (_showNewForm) _buildNewSessionForm(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => setState(() => _showNewForm = true),
        backgroundColor: InkFlowColors.accent,
        foregroundColor: InkFlowColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Novo Agendamento'),
      ),
    );
  }

  Widget _buildNewSessionForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -4))
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Agendar para ${_weekDays[_selectedDay]}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _showNewForm = false),
                ),
              ],
            ),
            if (_conflictError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _conflictError!,
                  style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                ),
              ),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Nome do Cliente',
                filled: true,
              ),
              validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
              onSaved: (v) => _newClient = v!,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Horário Início',
                      hintText: '09:00',
                      filled: true,
                    ),
                    validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                    onSaved: (v) => _newStartTime = v!,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Horário Fim',
                      hintText: '11:00',
                      filled: true,
                    ),
                    validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                    onSaved: (v) => _newEndTime = v!,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Serviço / Estilo',
                filled: true,
              ),
              onSaved: (v) => _newStyle = v ?? 'Indefinido',
            ),
            const SizedBox(height: 16),
            InkButton(label: 'Salvar Agendamento', onPressed: _handleSave),
          ],
        ),
      ),
    );
  }
}
