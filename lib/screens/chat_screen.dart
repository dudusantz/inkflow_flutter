import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

enum ChatScenario { validProposal, pastDate, acceptProposal }

class _Message {
  final int id;
  final bool fromClient;
  final String? text;
  final _Proposal? proposal;
  _Message({required this.id, required this.fromClient, this.text, this.proposal});
}

class _Proposal {
  final String value;
  final String date;
  final String time;
  String status; // pending, accepted, refused
  _Proposal({required this.value, required this.date, required this.time, this.status = 'pending'});
}

const _artistsMap = {
  '1': {'name': 'Ana Ferreira', 'avatar': 'https://images.unsplash.com/photo-1612271974453-15e684c6586b?w=80&h=80&fit=crop&crop=face', 'status': 'Online agora'},
  '2': {'name': 'Rafael Costa', 'avatar': 'https://images.unsplash.com/photo-1544604725-0ffa9861dec2?w=80&h=80&fit=crop&crop=face', 'status': 'Visto há 5 min'},
  '3': {'name': 'Julia Mendes', 'avatar': 'https://images.unsplash.com/photo-1531746020798-e6953c6e8e04?w=80&h=80&fit=crop&crop=face', 'status': 'Online agora'},
};

class ChatScreen extends StatefulWidget {
  final String artistId;
  const ChatScreen({super.key, this.artistId = '1'});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  ChatScenario _scenario = ChatScenario.validProposal;
  bool _showProposalForm = false;
  String _proposalValue = 'R\$ 800';
  String _proposalDate = '2026-08-20';
  String _proposalTime = '14:00';
  _Proposal? _sentProposal;
  String _clientProposalStatus = 'pending';

  late Map<String, String> _artist;
  final _scrollController = ScrollController();

  final _defaultMessages = [
    _Message(id: 1, fromClient: true, text: 'Oi! Quero fazer uma tatuagem geométrica no antebraço. Qual é o valor?'),
    _Message(id: 2, fromClient: false, text: 'Olá! Para uma geométrica no antebraço, o valor base é R\$ 700–900. Posso te enviar uma proposta formal?'),
    _Message(id: 3, fromClient: true, text: 'Sim, por favor! Qual é a disponibilidade?'),
  ];

  late List<_Message> _messages;

  @override
  void initState() {
    super.initState();
    _artist = Map<String, String>.from(
        _artistsMap[widget.artistId] ?? _artistsMap['1']!);
    _messages = List.from(_defaultMessages);
  }

  bool get _isClientPerspective => _scenario == ChatScenario.acceptProposal;

  bool get _isPastDate {
    if (_proposalDate.isEmpty) return false;
    try {
      final date = DateTime.parse(_proposalDate);
      return date.isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  void _applyScenario(ChatScenario s) {
    setState(() {
      _scenario = s;
      _showProposalForm = false;
      _sentProposal = null;
      _clientProposalStatus = 'pending';
      _messages = List.from(_defaultMessages);
      if (s == ChatScenario.pastDate) {
        _proposalDate = '2025-01-10';
      } else {
        _proposalDate = '2026-08-20';
      }
    });
  }

  void _sendProposal() {
    if (_isPastDate && _scenario != ChatScenario.acceptProposal) return;
    final proposal = _Proposal(
      value: _proposalValue,
      date: _proposalDate,
      time: _proposalTime,
    );
    setState(() {
      _sentProposal = proposal;
      _showProposalForm = false;
      _messages.add(_Message(
        id: _messages.length + 1,
        fromClient: false,
        proposal: proposal,
      ));
    });
  }

  void _handleAcceptProposal() {
    setState(() => _clientProposalStatus = 'accepted');
  }

  void _handleRefuseProposal() {
    setState(() => _clientProposalStatus = 'refused');
  }

  @override
  Widget build(BuildContext context) {
    // Build messages for client perspective
    final displayMessages = _isClientPerspective
        ? [
            ..._defaultMessages,
            _Message(
              id: 99,
              fromClient: false,
              proposal: _Proposal(
                value: 'R\$ 800',
                date: '2026-08-20',
                time: '14:00',
                status: _clientProposalStatus,
              ),
            ),
          ]
        : _messages;

    return Scaffold(
      body: Column(
        children: [
          ScenarioSwitcher(
            rf: 'RF04/05',
            active: _scenario.name,
            scenarios: const [
              ScenarioConfig(key: 'validProposal', label: '✓ Proposta Válida', color: ScenarioColor.green),
              ScenarioConfig(key: 'pastDate', label: '✗ Data Passada', color: ScenarioColor.red),
              ScenarioConfig(key: 'acceptProposal', label: '⚠ Aceite (Cliente)', color: ScenarioColor.yellow),
            ],
            onChange: (k) => _applyScenario(
                ChatScenario.values.firstWhere((e) => e.name == k)),
          ),

          // Header do chat
          Container(
            color: InkFlowColors.primary,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.go('/home'),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.chevron_left,
                            color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    AvatarImage(url: _artist['avatar']!, size: 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_artist['name']!,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                          Text(_artist['status']!,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 11)),
                        ],
                      ),
                    ),
                    Text(
                      _isClientPerspective ? '👤 Cliente' : '🎨 Tatuador',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.5), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Mensagens
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: displayMessages.length,
              itemBuilder: (context, i) {
                final msg = displayMessages[i];
                final isMe = _isClientPerspective ? msg.fromClient : !msg.fromClient;
                if (msg.proposal != null) {
                  return _buildProposalCard(msg.proposal!, isMe);
                }
                return _buildTextBubble(msg.text ?? '', isMe);
              },
            ),
          ),

          // Formulário de proposta
          if (_showProposalForm) _buildProposalForm(),

          // Input bar
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildTextBubble(String text, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? InkFlowColors.accent : Colors.white,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 1))
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isMe ? InkFlowColors.primary : Colors.grey.shade800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildProposalCard(_Proposal proposal, bool isMe) {
    final isClientView = _isClientPerspective;
    Color statusColor = Colors.grey;
    String statusText = 'Aguardando resposta...';
    if (proposal.status == 'accepted') {
      statusColor = const Color(0xFF10B981);
      statusText = '✓ Proposta Aceita — Agendado!';
    } else if (proposal.status == 'refused') {
      statusColor = const Color(0xFFEF4444);
      statusText = '✗ Proposta Recusada';
    }

    String formattedDate = proposal.date;
    try {
      final d = DateTime.parse(proposal.date);
      formattedDate = DateFormat("dd/MM/yyyy", 'pt_BR').format(d);
    } catch (_) {}

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        width: MediaQuery.of(context).size.width * 0.78,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: InkFlowColors.accent.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: InkFlowColors.primary,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.assignment, color: InkFlowColors.accent, size: 16),
                  const SizedBox(width: 8),
                  const Text('Proposta de Agendamento',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _proposalRow('💰 Valor', proposal.value),
                  const SizedBox(height: 6),
                  _proposalRow('📅 Data', formattedDate),
                  const SizedBox(height: 6),
                  _proposalRow('⏰ Horário', proposal.time),
                  const SizedBox(height: 12),

                  // Status ou botões
                  if (proposal.status == 'pending' && isClientView)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _handleAcceptProposal,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: const Text('Aceitar',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _handleRefuseProposal,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: const Text('Recusar',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(statusText,
                          style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _proposalRow(String label, String value) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        const SizedBox(width: 8),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: InkFlowColors.primary)),
      ],
    );
  }

  Widget _buildProposalForm() {
    final isPast = _isPastDate && _scenario != ChatScenario.acceptProposal;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, -4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('Nova Proposta',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const Spacer(),
              GestureDetector(
                  onTap: () => setState(() => _showProposalForm = false),
                  child: const Icon(Icons.close, size: 20)),
            ],
          ),
          const SizedBox(height: 12),

          // Valor
          _formRow('Valor (R\$)',
              TextFormField(
                initialValue: 'R\$ 800',
                onChanged: (v) => _proposalValue = v,
                decoration: _inputDec('Ex: R\$ 800'),
              )),
          const SizedBox(height: 10),

          // Data
          Row(
            children: [
              Expanded(
                child: _formRow('Data',
                    GestureDetector(
                      onTap: _pickProposalDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: isPast
                                  ? const Color(0xFFEF4444)
                                  : Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Text(_proposalDate,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: isPast
                                        ? const Color(0xFFEF4444)
                                        : Colors.grey.shade800)),
                            const Spacer(),
                            const Icon(Icons.calendar_today, size: 14),
                          ],
                        ),
                      ),
                    )),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _formRow('Horário',
                    TextFormField(
                      initialValue: _proposalTime,
                      onChanged: (v) => setState(() => _proposalTime = v),
                      decoration: _inputDec('14:00'),
                    )),
              ),
            ],
          ),

          if (isPast) ...[
            const SizedBox(height: 8),
            const Text(
              '⚠ A data do agendamento não pode ser no passado',
              style: TextStyle(color: Color(0xFFEF4444), fontSize: 11),
            ),
          ],
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isPast ? null : _sendProposal,
              style: ElevatedButton.styleFrom(
                backgroundColor: InkFlowColors.accent,
                foregroundColor: InkFlowColors.primary,
                disabledBackgroundColor: Colors.grey.shade200,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Enviar Proposta',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formRow(String label, Widget field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        field,
      ],
    );
  }

  InputDecoration _inputDec(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      isDense: true,
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Botão de proposta (só para tatuador)
            if (!_isClientPerspective)
              GestureDetector(
                onTap: () => setState(() => _showProposalForm = !_showProposalForm),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: InkFlowColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: InkFlowColors.accent.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.assignment_add,
                      color: InkFlowColors.accent, size: 18),
                ),
              ),
            if (!_isClientPerspective) const SizedBox(width: 8),

            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Mensagem...',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                  color: InkFlowColors.accent, shape: BoxShape.circle),
              child: const Icon(Icons.send, color: InkFlowColors.primary, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickProposalDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _proposalDate =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }
}
