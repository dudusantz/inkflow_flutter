import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:inkflow/core/errors/error_utils.dart';
import 'package:inkflow/core/theme/app_theme.dart';
import 'package:inkflow/core/widgets/shared_widgets.dart';
import 'package:inkflow/features/chat/data/chat_repository.dart';
import 'package:inkflow/features/chat/domain/chat_message.dart';
import 'package:inkflow/features/profile/providers/profile_provider.dart';

final chatStreamProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, String>((ref, contactId) {
  return ref.watch(chatRepositoryProvider).watchConversation(contactId);
});

final chatContactProvider =
    FutureProvider.autoDispose.family<ChatContact?, String>((ref, contactId) {
  return ref.watch(chatRepositoryProvider).fetchContact(contactId);
});

class ChatScreen extends ConsumerStatefulWidget {
  /// Id do outro participante da conversa.
  final String contactId;

  const ChatScreen({super.key, required this.contactId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await ref.read(chatRepositoryProvider).sendMessage(
            receiverId: widget.contactId,
            content: text,
          );
    } catch (e) {
      if (!mounted) return;
      // Devolve o texto ao campo para o usuário não perder o que escreveu.
      _messageController.text = text;
      showErrorSnackBar(context, userFriendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showProposalUnavailable() {
    showErrorSnackBar(
      context,
      'O envio de propostas ainda não está disponível.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArtist = ref.watch(isArtistProvider);
    final messagesAsync = ref.watch(chatStreamProvider(widget.contactId));
    final contact = ref.watch(chatContactProvider(widget.contactId)).value;

    return Scaffold(
      backgroundColor: InkFlowColors.background,
      appBar: _buildAppBar(contact),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: messagesAsync.when(
                loading: () => const Center(
                    child:
                        CircularProgressIndicator(color: InkFlowColors.accent)),
                error: (e, s) => AsyncErrorView(
                  error: e,
                  customMessage: 'Erro ao carregar a conversa.',
                  onRetry: () =>
                      ref.invalidate(chatStreamProvider(widget.contactId)),
                ),
                data: (messages) {
                  if (messages.isEmpty) {
                    return const Center(
                      child: Text('Nenhuma mensagem. Comece a conversa!',
                          style: TextStyle(color: Color(0xFF6B7280))),
                    );
                  }

                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 20),
                    itemCount: messages.length,
                    itemBuilder: (context, index) =>
                        _MessageBubble(message: messages[index]),
                  );
                },
              ),
            ),
            _buildInputArea(isArtist),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ChatContact? contact) {
    return AppBar(
      backgroundColor: InkFlowColors.primary,
      elevation: 0,
      leading: IconButton(
        icon:
            const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
        tooltip: 'Voltar',
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/inbox');
          }
        },
      ),
      title: Row(
        children: [
          AvatarImage(url: contact?.avatarUrl, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              contact?.name ?? 'Conversa',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
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
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4))
      ]),
      child: Row(
        children: [
          if (isArtist) ...[
            // A proposta formal (RF04/RF05) ainda não tem tabela no banco. O
            // botão permanece visível, mas assume explicitamente que não
            // funciona em vez de abrir um formulário que descarta os dados.
            IconButton(
              icon: const Icon(Icons.request_quote_outlined,
                  color: Color(0xFF6B7280)),
              tooltip: 'Enviar proposta (em desenvolvimento)',
              onPressed: _showProposalUnavailable,
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(24)),
              child: TextField(
                controller: _messageController,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                    hintText: 'Escreva uma mensagem...',
                    hintStyle:
                        TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                    border: InputBorder.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
                color: InkFlowColors.accent, shape: BoxShape.circle),
            child: IconButton(
              icon:
                  const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              tooltip: 'Enviar',
              onPressed: _isSending ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isMine ? InkFlowColors.primary : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft:
                          isMine ? const Radius.circular(16) : Radius.zero,
                      bottomRight:
                          isMine ? Radius.zero : const Radius.circular(16),
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Text(message.content,
                      style: TextStyle(
                          color:
                              isMine ? Colors.white : const Color(0xFF1F2937),
                          fontSize: 14)),
                ),
                const SizedBox(height: 4),
                Text(message.timeLabel,
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
