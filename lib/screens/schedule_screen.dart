import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

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

  // Estado Local (Simulando o Banco de Dados)
  final List<Map<String, dynamic>> _sessions = [
    {'time': '09:00', 'date': 'Ter', 'client': 'Carlos Mendes', 'style': 'Geométrico', 'duration': '2h'},
    {'time': '14:00', 'date': 'Qua', 'client': 'Fernanda Lima', 'style': 'Black Work', 'duration': '3h'},
  ];

  // Variáveis do Form
  String _newClient = '';
  String _newTime = '';
  String _newStyle = '';
  String _newDuration = '2h';
  final List<String> _weekDays = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];

  void _handleSave() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      // Validação de Conflito de Horário (RF06)
      final hasConflict = _sessions.any((s) => 
        s['time'] == _newTime && s['date'] == _weekDays[_selectedDay]
      );

      if (hasConflict) {
        setState(() => _conflictError = 'Já existe uma sessão agendada para este horário.');
        return;
      }

      // Salva no estado
      setState(() {
        _sessions.add({
          'time': _newTime,
          'date': _weekDays[_selectedDay],
          'client': _newClient,
          'style': _newStyle,
          'duration': _newDuration,
        });
        
        // Ordena por horário simples
        _sessions.sort((a, b) => a['time'].compareTo(b['time']));
        
        _showNewForm = false;
        _conflictError = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agendamento salvo!'), backgroundColor: Color(0xFF10B981)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filtra as sessões para o dia selecionado
    final daySessions = _sessions.where((s) => s['date'] == _weekDays[_selectedDay]).toList();

    return Scaffold(
      body: Column(
        children: [
          AppHeader(
            title: 'Agenda',
            showBack: true,
            backTo: '/home',
            rightElement: GestureDetector(
              onTap: () => setState(() => _showNewForm = true),
              child: const Icon(Icons.add_circle, color: InkFlowColors.accent, size: 28),
            ),
          ),
          
          // Seletor de Semana (Simplificado)
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
                    backgroundColor: isSelected ? InkFlowColors.primary : Colors.transparent,
                    radius: 20,
                    child: Text(
                      _weekDays[i],
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.white : Colors.grey.shade600,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
                      child: ListTile(
                        leading: Text(s['time'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        title: Text(s['client']),
                        subtitle: Text('${s['style']} • ${s['duration']}'),
                      ),
                    );
                  }
                ),
          ),

          if (_showNewForm) _buildNewSessionForm(),
        ],
      ),
    );
  }

  Widget _buildNewSessionForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -4))],
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
                Text('Agendar para ${_weekDays[_selectedDay]}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _showNewForm = false)),
              ],
            ),
            if (_conflictError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_conflictError!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
              ),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Cliente', filled: true),
              validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
              onSaved: (v) => _newClient = v!,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(labelText: 'Horário (ex: 14:00)', filled: true),
                    validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                    onSaved: (v) => _newTime = v!,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(labelText: 'Estilo', filled: true),
                    onSaved: (v) => _newStyle = v ?? 'Indefinido',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InkButton(label: 'Salvar Agendamento', onPressed: _handleSave),
          ],
        ),
      ),
    );
  }
}