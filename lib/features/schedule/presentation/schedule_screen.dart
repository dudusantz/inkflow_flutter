import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:inkflow/core/errors/error_utils.dart';
import 'package:inkflow/core/theme/app_theme.dart';
import 'package:inkflow/core/utils/time_slot.dart';
import 'package:inkflow/core/widgets/shared_widgets.dart';
import 'package:inkflow/features/profile/providers/profile_provider.dart';
import 'package:inkflow/features/schedule/data/appointment_repository.dart';
import 'package:inkflow/features/schedule/domain/appointment.dart';

final scheduleProvider = FutureProvider.autoDispose<List<Appointment>>((ref) {
  final isArtist = ref.watch(isArtistProvider);
  return ref.watch(appointmentRepositoryProvider).listForUser(asArtist: isArtist);
});

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  static const _weekDays = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];

  final _formKey = GlobalKey<FormState>();
  final _clientController = TextEditingController();
  final _styleController = TextEditingController();

  bool _showNewForm = false;
  bool _isSaving = false;
  String? _conflictError;

  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void dispose() {
    _clientController.dispose();
    _styleController.dispose();
    super.dispose();
  }

  List<DateTime> _currentWeek() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysSinceSunday = today.weekday == 7 ? 0 : today.weekday;
    final sunday = today.subtract(Duration(days: daysSinceSunday));
    return List.generate(7, (i) => sunday.add(Duration(days: i)));
  }

  String _format(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (isStart ? _startTime : _endTime) ??
          const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked == null) return;

    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
      _conflictError = null;
    });
  }

  void _closeForm() {
    setState(() {
      _showNewForm = false;
      _conflictError = null;
      _startTime = null;
      _endTime = null;
      _clientController.clear();
      _styleController.clear();
    });
  }

  Future<void> _handleSave(List<Appointment> currentSessions) async {
    if (!_formKey.currentState!.validate()) return;

    final start = _startTime;
    final end = _endTime;
    if (start == null || end == null) {
      setState(() => _conflictError = 'Informe o horário de início e de fim.');
      return;
    }

    final slot = TimeSlot.tryParse(_format(start), _format(end));
    if (slot == null) {
      setState(() =>
          _conflictError = 'O horário de fim deve ser depois do de início.');
      return;
    }

    // Pré-checagem local só para dar feedback imediato. A garantia real é a
    // constraint de exclusão no banco, checada no catch abaixo — duas gravações
    // simultâneas passariam por esta verificação.
    final hasConflict = currentSessions
        .where((s) => s.isOn(_selectedDate))
        .any((s) => s.slot?.overlaps(slot) ?? false);

    if (hasConflict) {
      setState(() => _conflictError =
          'Existe um conflito de horário com uma sessão já agendada.');
      return;
    }

    setState(() {
      _isSaving = true;
      _conflictError = null;
    });

    try {
      await ref.read(appointmentRepositoryProvider).create(
            NewAppointment(
              clientName: _clientController.text.trim(),
              date: _selectedDate,
              startTime: _format(start),
              endTime: _format(end),
              style: _styleController.text.trim().isEmpty
                  ? 'Indefinido'
                  : _styleController.text.trim(),
            ),
          );

      ref.invalidate(scheduleProvider);
      if (!mounted) return;

      _closeForm();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agendamento salvo com sucesso!'),
          backgroundColor: InkFlowColors.success,
        ),
      );
    } on AppointmentConflictException {
      if (!mounted) return;
      setState(() => _conflictError =
          'Este horário acabou de ser ocupado. Escolha outro.');
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, userFriendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _toggleReminder(Appointment appointment) async {
    try {
      await ref
          .read(appointmentRepositoryProvider)
          .setReminderEnabled(appointment.id, !appointment.reminderEnabled);
      ref.invalidate(scheduleProvider);
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, userFriendlyErrorMessage(e));
    }
  }

  void _openSessionDetails(Appointment session, bool isArtist) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isArtist
                    ? 'Cliente: ${session.clientName}'
                    : 'Sessão confirmada',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '${DateFormat('dd/MM/yyyy').format(session.date)} • '
                '${session.timeRangeLabel}',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              Text('Estilo: ${session.style}',
                  style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 20),
              if (isArtist)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enviar lembrete automático de 24h',
                      style: TextStyle(fontSize: 14)),
                  subtitle: const Text(
                      'Desative para cancelar o envio do lembrete desta sessão.',
                      style: TextStyle(fontSize: 11)),
                  value: session.reminderEnabled,
                  activeThumbColor: InkFlowColors.accent,
                  onChanged: (_) {
                    Navigator.pop(sheetContext);
                    _toggleReminder(session);
                  },
                )
              else
                Row(
                  children: [
                    Icon(
                      session.reminderEnabled
                          ? Icons.notifications_active
                          : Icons.notifications_off,
                      color: InkFlowColors.accent,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      session.reminderEnabled
                          ? 'Lembrete automático ativado'
                          : 'Lembrete automático desativado',
                      style: const TextStyle(
                          color: InkFlowColors.primary,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: InkFlowColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Fechar Detalhes'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArtist = ref.watch(isArtistProvider);
    final scheduleAsync = ref.watch(scheduleProvider);
    final weekDates = _currentWeek();

    return Scaffold(
      body: Column(
        children: [
          const AppHeader(title: 'Agenda'),
          _buildWeekSelector(weekDates),
          Expanded(
            child: scheduleAsync.when(
              loading: () => const Center(
                  child:
                      CircularProgressIndicator(color: InkFlowColors.accent)),
              error: (e, s) => AsyncErrorView(
                error: e,
                customMessage: 'Erro ao carregar agenda.',
                onRetry: () => ref.invalidate(scheduleProvider),
              ),
              data: (allSessions) {
                final daySessions = allSessions
                    .where((s) => s.isOn(_selectedDate))
                    .toList();

                if (daySessions.isEmpty) {
                  return Center(
                    child: Text(
                      isArtist
                          ? 'Sua agenda está livre neste dia.'
                          : 'Você não possui sessões neste dia.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: daySessions.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, i) => _SessionTile(
                    session: daySessions[i],
                    isArtist: isArtist,
                    onTap: () => _openSessionDetails(daySessions[i], isArtist),
                  ),
                );
              },
            ),
          ),
          if (_showNewForm && isArtist)
            scheduleAsync.maybeWhen(
              data: _buildNewSessionForm,
              orElse: () => const SizedBox.shrink(),
            ),
        ],
      ),
      floatingActionButton: isArtist && !_showNewForm
          ? FloatingActionButton.extended(
              onPressed: () => setState(() => _showNewForm = true),
              backgroundColor: InkFlowColors.accent,
              foregroundColor: InkFlowColors.primary,
              icon: const Icon(Icons.add),
              label: const Text('Novo Agendamento',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }

  Widget _buildWeekSelector(List<DateTime> weekDates) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(7, (i) {
          final date = weekDates[i];
          final isSelected = date.year == _selectedDate.year &&
              date.month == _selectedDate.month &&
              date.day == _selectedDate.day;

          return Semantics(
            selected: isSelected,
            button: true,
            label: DateFormat('EEEE, d/MM', 'pt_BR').format(date),
            child: ExcludeSemantics(
              child: GestureDetector(
                onTap: () => setState(() => _selectedDate = date),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? InkFlowColors.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _weekDays[i],
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected
                              ? Colors.white70
                              : Colors.grey.shade500,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 16,
                          color: isSelected
                              ? Colors.white
                              : InkFlowColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNewSessionForm(List<Appointment> currentSessions) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 10, offset: Offset(0, -4))
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
                  'Agendar para ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Fechar formulário',
                  onPressed: _closeForm,
                ),
              ],
            ),
            if (_conflictError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_conflictError!,
                    style: const TextStyle(
                        color: InkFlowColors.error, fontSize: 12)),
              ),
            TextFormField(
              controller: _clientController,
              decoration: _fieldDecoration('Nome do Cliente'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
            ),
            const SizedBox(height: 8),
            // Seletor de hora em vez de texto livre: antes um "9h" digitado
            // virava zero minutos silenciosamente e invalidava a checagem de
            // conflito.
            Row(
              children: [
                Expanded(
                  child: _TimeField(
                    label: 'Início',
                    value: _startTime,
                    format: _format,
                    onTap: () => _pickTime(isStart: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TimeField(
                    label: 'Fim',
                    value: _endTime,
                    format: _format,
                    onTap: () => _pickTime(isStart: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _styleController,
              decoration: _fieldDecoration('Estilo da Tatuagem'),
            ),
            const SizedBox(height: 16),
            InkButton(
              label: 'Salvar Agendamento',
              isLoading: _isSaving,
              onPressed: () => _handleSave(currentSessions),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none),
    );
  }
}

class _TimeField extends StatelessWidget {
  final String label;
  final TimeOfDay? value;
  final String Function(TimeOfDay) format;
  final VoidCallback onTap;

  const _TimeField({
    required this.label,
    required this.value,
    required this.format,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
        ),
        child: Text(
          value == null ? '--:--' : format(value!),
          style: TextStyle(
            fontSize: 16,
            color: value == null ? Colors.grey.shade500 : Colors.black87,
          ),
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final Appointment session;
  final bool isArtist;
  final VoidCallback onTap;

  const _SessionTile({
    required this.session,
    required this.isArtist,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: ListTile(
        onTap: onTap,
        leading: Text(
          session.startTime,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        title: Text(
          isArtist ? session.clientName : 'Tatuador Parceiro',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('${session.style} • ${session.timeRangeLabel}'),
        trailing: isArtist
            ? Icon(
                session.reminderEnabled
                    ? Icons.notifications_active
                    : Icons.notifications_off,
                color: session.reminderEnabled
                    ? InkFlowColors.accent
                    : Colors.grey,
                size: 20,
              )
            : const Icon(Icons.arrow_forward_ios,
                size: 14, color: Colors.grey),
      ),
    );
  }
}
