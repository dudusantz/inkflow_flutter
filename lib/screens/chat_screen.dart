import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

// Modelos Reais para gerenciar o Estado
class Message {
  final String text;
  final bool isMe;
  final Proposal? proposal;
  Message({this.text = '', required this.isMe, this.proposal});
}

class Proposal {
  final String date;
  final String time;
  final String value;
  String status; // pending, accepted, refused
  Proposal({required this.date, required this.time, required this.value, this.status = 'pending'});
}

class ChatScreen extends StatefulWidget {
  final String artistId;
  const ChatScreen({super.key, this.artistId = '1'});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final List<Message> _messages = [];
  bool _showProposalForm = false;

  // Variáveis da Proposta
  DateTime? _proposalDate;
  String _proposalTime = '14:00';
  String _proposalValue = '';

  // Simula se quem está logado é Cliente ou Tatuador (Isso viria do AuthProvider)
  final bool _isClientUser = false; // Mude para true para testar a visão do cliente

  void _sendMessage() {
    if (_msgController.text.trim().isEmpty) return;
    setState(() {
      _messages.add(Message(text: _msgController.text, isMe: true));
      _msgController.clear();
    });
  }

  void _sendProposal() {
    if (_proposalDate == null || _proposalValue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha data e valor.')));
      return;
    }
    
    // Validação de Horário no Passado (RF04)
    if (_proposalDate!.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A data não pode ser no passado!'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _messages.add(Message(
        isMe: true,
        proposal: Proposal(
          date: '${_proposalDate!.day}/${_proposalDate!.month}/${_proposalDate!.year}',
          time: _proposalTime,
          value: _proposalValue
        )
      ));
      _showProposalForm = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat'), backgroundColor: InkFlowColors.primary, foregroundColor: Colors.white),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                if (msg.proposal != null) return _buildProposalCard(msg.proposal!, msg.isMe);
                return _buildTextBubble(msg.text, msg.isMe);
              },
            ),
          ),
          
          if (_showProposalForm) _buildProposalForm(),
          
          // Input Area
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: Row(
              children: [
                if (!_isClientUser)
                  IconButton(
                    icon: const Icon(Icons.assignment_add, color: InkFlowColors.accent),
                    onPressed: () => setState(() => _showProposalForm = !_showProposalForm),
                  ),
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: const InputDecoration(hintText: 'Digite uma mensagem...', border: InputBorder.none),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send, color: InkFlowColors.primary), onPressed: _sendMessage),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTextBubble(String text, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? InkFlowColors.accent.withOpacity(0.2) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(text),
      ),
    );
  }

  Widget _buildProposalCard(Proposal p, bool isMe) {
    return Card(
      color: InkFlowColors.primary,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Proposta de Agendamento', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Data: ${p.date} às ${p.time}', style: const TextStyle(color: Colors.white70)),
            Text('Valor: R\$ ${p.value}', style: const TextStyle(color: InkFlowColors.accent, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            
            // RF05: Lógica de Aceite pelo Cliente
            if (p.status == 'pending' && (!isMe || _isClientUser))
               Row(
                 children: [
                   ElevatedButton(
                     style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                     onPressed: () => setState(() => p.status = 'accepted'), 
                     child: const Text('Aceitar')
                   ),
                   const SizedBox(width: 8),
                   ElevatedButton(
                     style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                     onPressed: () => setState(() => p.status = 'refused'), 
                     child: const Text('Recusar')
                   ),
                 ],
               )
            else
               Text('Status: ${p.status.toUpperCase()}', style: TextStyle(color: p.status == 'accepted' ? Colors.green : Colors.red)),
          ],
        ),
      ),
    );
  }

  Widget _buildProposalForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nova Proposta', style: TextStyle(fontWeight: FontWeight.bold)),
          TextField(decoration: const InputDecoration(labelText: 'Valor'), onChanged: (v) => _proposalValue = v),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(_proposalDate == null ? 'Selecionar Data' : '${_proposalDate!.day}/${_proposalDate!.month}'),
                  onPressed: () async {
                    final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                    setState(() => _proposalDate = date);
                  },
                ),
              ),
              Expanded(child: TextField(decoration: const InputDecoration(labelText: 'Hora'), onChanged: (v) => _proposalTime = v)),
            ],
          ),
          ElevatedButton(onPressed: _sendProposal, child: const Text('Enviar Proposta')),
        ],
      ),
    );
  }
}