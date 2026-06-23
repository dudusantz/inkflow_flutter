import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inkflow/core/theme/app_theme.dart';
import 'package:inkflow/features/home/presentation/home_screen.dart';

// --- MODELOS DE DADOS ---
class Proposal {
  final String date;
  final String time;
  final String value;
  String status;

  Proposal({
    required this.date,
    required this.time,
    required this.value,
    this.status = 'pending',
  });
}

class ChatMessage {
  final String? text;
  final String? image;
  final bool isMe;
  final String time;
  final Proposal? proposal;

  ChatMessage({
    this.text,
    this.image,
    required this.isMe,
    required this.time,
    this.proposal,
  });
}

// --- PROVIDER DE TEMPO REAL (WEBSOCKETS) ---
// Escuta a tabela 'messages' do Supabase e atualiza a UI instantaneamente
final chatStreamProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, String>((ref, otherUserId) {
  final supabase = Supabase.instance.client;
  final myId = supabase.auth.currentUser?.id;

  if (myId == null) return Stream.value([]);

  return supabase
      .from('messages')
      .stream(primaryKey: ['id'])
      .order('created_at',
          ascending: false) // Ordem inversa para o ListView.reverse
      .map((data) {
        // Filtra para pegar só as mensagens entre você e a outra pessoa
        final filtered = data.where((m) =>
            (m['sender_id'] == myId && m['receiver_id'] == otherUserId) ||
            (m['sender_id'] == otherUserId && m['receiver_id'] == myId));

        return filtered.map((m) {
          final createdAt =
              DateTime.tryParse(m['created_at'].toString())?.toLocal() ??
                  DateTime.now();
          return ChatMessage(
            text: m['content'],
            isMe: m['sender_id'] == myId,
            time:
                '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
          );
        }).toList();
      });
});

// --- TELA DE CHAT ---
class ChatScreen extends ConsumerStatefulWidget {
  final String artistId;
  const ChatScreen({super.key, required this.artistId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();

  bool _showProposalForm = false;
  DateTime? _proposalDate;
  String _proposalTime = '14:00';
  String _proposalValue = '';
  static const _unavailableSlots = {'09:00', '9:00'};

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  // Envio Real para o Banco de Dados
  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    _msgController.clear(); // Limpa o input imediatamente (boa UX)

    final supabase = Supabase.instance.client;
    final myId = supabase.auth.currentUser?.id;

    if (myId == null) return;

    try {
      await supabase.from('messages').insert({
        'sender_id': myId,
        'receiver_id': widget.artistId,
        'content': text,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Erro ao enviar mensagem.'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  bool get _isProposalDatePast {
    if (_proposalDate == null) return false;
    final today = DateTime.now();
    final d =
        DateTime(_proposalDate!.year, _proposalDate!.month, _proposalDate!.day);
    final t = DateTime(today.year, today.month, today.day);
    return d.isBefore(t);
  }

  void _acceptProposal(Proposal p) {
    if (_unavailableSlots.contains(p.time.trim())) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Horário indisponível'),
          content: const Text('O horário não está mais disponível'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
          ],
        ),
      );
      setState(() => p.status = 'expired');
      return;
    }
    setState(() => p.status = 'accepted');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Agendamento confirmado!'),
          backgroundColor: Color(0xFF10B981)),
    );
  }

  void _sendProposal() {
    // Nota: A proposta ainda é local. Em breve precisaremos criar uma tabela 'proposals'.
    if (_proposalDate == null || _proposalValue.isEmpty || _isProposalDatePast)
      return;
    setState(() => _showProposalForm = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Proposta enviada (Requer integração com banco)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userRoleAsync = ref.watch(userRoleProvider);
    final String role = userRoleAsync.value ?? 'CLIENT';
    final bool isArtist = role == 'ARTIST';

    // Escuta o stream de mensagens do Supabase
    final messagesAsync = ref.watch(chatStreamProvider(widget.artistId));

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F5),
      appBar: _buildAppBar(isArtist),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: messagesAsync.when(
                loading: () => const Center(
                    child:
                        CircularProgressIndicator(color: InkFlowColors.accent)),
                error: (e, s) =>
                    Center(child: Text('Erro ao carregar chat: $e')),
                data: (messages) {
                  if (messages.isEmpty) {
                    return const Center(
                      child: Text('Nenhuma mensagem. Comece a conversa!',
                          style: TextStyle(color: Colors.grey)),
                    );
                  }
                  return ListView.builder(
                    reverse:
                        true, // Arquitetura Sênior: Faz a lista empilhar de baixo para cima
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 20),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      if (msg.proposal != null)
                        return _buildProposalCard(
                            msg.proposal!, msg.isMe, isArtist);
                      return _buildMessageBubble(msg);
                    },
                  );
                },
              ),
            ),
            if (_showProposalForm && isArtist) _buildProposalForm(),
            _buildInputArea(isArtist),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isArtist) {
    return AppBar(
      backgroundColor: InkFlowColors.primary,
      elevation: 0,
      leading: IconButton(
        icon:
            const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        },
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: NetworkImage(isArtist
                ? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100&h=100&fit=crop'
                : 'https://images.unsplash.com/photo-1544604725-0ffa9861dec2?w=150&fit=crop&crop=face'),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isArtist ? 'Eduardo (Cliente)' : 'Tatuador',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
              const Text('Online',
                  style: TextStyle(color: Color(0xFF10B981), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final hasImage = msg.image != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            msg.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment:
                  msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: hasImage
                      ? const EdgeInsets.all(4)
                      : const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: msg.isMe ? InkFlowColors.primary : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft:
                          msg.isMe ? const Radius.circular(16) : Radius.zero,
                      bottomRight:
                          msg.isMe ? Radius.zero : const Radius.circular(16),
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: hasImage
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(msg.image!,
                              width: 200, height: 200, fit: BoxFit.cover))
                      : Text(msg.text!,
                          style: TextStyle(
                              color: msg.isMe
                                  ? Colors.white
                                  : const Color(0xFF1F2937),
                              fontSize: 14)),
                ),
                const SizedBox(height: 4),
                Text(msg.time,
                    style:
                        TextStyle(color: Colors.grey.shade500, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- CARD DE PROPOSTA PREMIUM ---
  Widget _buildProposalCard(Proposal p, bool isMe, bool isArtist) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 260,
          decoration: BoxDecoration(
            color: InkFlowColors.primary,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: InkFlowColors.accent.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                    color: InkFlowColors.accent.withOpacity(0.1),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16))),
                child: const Row(
                  children: [
                    Icon(Icons.assignment_turned_in,
                        color: InkFlowColors.accent, size: 16),
                    SizedBox(width: 8),
                    Text('PROPOSTA OFICIAL',
                        style: TextStyle(
                            color: InkFlowColors.accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 11)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_month,
                            color: Colors.white54, size: 14),
                        const SizedBox(width: 6),
                        Text('${p.date} às ${p.time}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.payments_outlined,
                            color: Colors.white54, size: 14),
                        const SizedBox(width: 6),
                        Text('R\$ ${p.value}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (p.status == 'pending') ...[
                      if (!isArtist)
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8)),
                                onPressed: () => _acceptProposal(p),
                                child: const Text('Aceitar Proposta',
                                    style: TextStyle(fontSize: 12)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: const Color(0xFFEF4444),
                                    elevation: 0,
                                    side: const BorderSide(
                                        color: Color(0xFFEF4444))),
                                onPressed: () =>
                                    setState(() => p.status = 'refused'),
                                child: const Text('Recusar',
                                    style: TextStyle(fontSize: 12)),
                              ),
                            ),
                          ],
                        )
                      else
                        const Center(
                            child: Text('Aguardando resposta do cliente...',
                                style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic))),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                            color: p.status == 'accepted'
                                ? const Color(0xFF10B981).withOpacity(0.2)
                                : p.status == 'expired'
                                    ? Colors.orange.withOpacity(0.2)
                                    : const Color(0xFFEF4444).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8)),
                        child: Center(
                          child: Text(
                            p.status == 'accepted'
                                ? 'PROPOSTA ACEITA'
                                : p.status == 'expired'
                                    ? 'CANCELADA / EXPIRADA'
                                    : 'PROPOSTA RECUSADA',
                            style: TextStyle(
                                color: p.status == 'accepted'
                                    ? const Color(0xFF10B981)
                                    : p.status == 'expired'
                                        ? Colors.orange
                                        : const Color(0xFFEF4444),
                                fontWeight: FontWeight.bold,
                                fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProposalForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nova Proposta de Agendamento',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: InkFlowColors.primary)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2030));
                    if (date != null) setState(() => _proposalDate = date);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 12),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                            _proposalDate == null
                                ? 'Data'
                                : '${_proposalDate!.day}/${_proposalDate!.month}',
                            style: TextStyle(
                                fontSize: 13,
                                color: _proposalDate == null
                                    ? Colors.grey
                                    : Colors.black)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8)),
                  child: TextField(
                      decoration: const InputDecoration(
                          hintText: 'Hora (ex: 14:00)',
                          border: InputBorder.none,
                          hintStyle: TextStyle(fontSize: 13)),
                      onChanged: (v) => _proposalTime = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8)),
            child: TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    hintText: 'Valor (ex: 450,00)',
                    border: InputBorder.none,
                    prefixText: 'R\$ '),
                onChanged: (v) => _proposalValue = v),
          ),
          const SizedBox(height: 12),
          if (_isProposalDatePast)
            const Text('A data do agendamento não pode ser no passado.',
                style: TextStyle(color: Color(0xFFEF4444), fontSize: 11)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: InkFlowColors.accent,
                  foregroundColor: InkFlowColors.primary,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              onPressed: (_proposalDate == null ||
                      _proposalValue.isEmpty ||
                      _isProposalDatePast)
                  ? null
                  : _sendProposal,
              child: const Text('Enviar para o Cliente',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(bool isArtist) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4))
      ]),
      child: Row(
        children: [
          IconButton(
              icon: const Icon(Icons.attach_file, color: Color(0xFF6B7280)),
              onPressed: () {}),
          if (isArtist) ...[
            Container(
              decoration: BoxDecoration(
                  color: _showProposalForm
                      ? InkFlowColors.primary
                      : const Color(0xFFF3F4F6),
                  shape: BoxShape.circle),
              child: IconButton(
                icon: Icon(Icons.request_quote,
                    color: _showProposalForm
                        ? InkFlowColors.accent
                        : const Color(0xFF6B7280)),
                onPressed: () =>
                    setState(() => _showProposalForm = !_showProposalForm),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(24)),
              child: TextField(
                controller: _msgController,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: const InputDecoration(
                    hintText: 'Escreve uma mensagem...',
                    hintStyle:
                        TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                    border: InputBorder.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
                color: InkFlowColors.accent, shape: BoxShape.circle),
            child: IconButton(
                icon: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 20),
                onPressed: _sendMessage),
          ),
        ],
      ),
    );
  }
}
