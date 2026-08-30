import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:inkflow/core/errors/error_utils.dart';
import 'package:inkflow/core/theme/app_theme.dart';
import 'package:inkflow/core/widgets/shared_widgets.dart';
import 'package:inkflow/features/chat/data/chat_repository.dart';
import 'package:inkflow/features/chat/domain/chat_message.dart';

final inboxProvider = StreamProvider.autoDispose<List<Conversation>>((ref) {
  return ref.watch(chatRepositoryProvider).watchInbox();
});

class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(inboxProvider);

    return Scaffold(
      backgroundColor: InkFlowColors.background,
      appBar: AppBar(
        backgroundColor: InkFlowColors.primary,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Mensagens',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
      ),
      body: conversationsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: InkFlowColors.accent)),
        error: (error, _) => AsyncErrorView(
          error: error,
          customMessage: 'Erro ao carregar as conversas.',
          onRetry: () => ref.invalidate(inboxProvider),
        ),
        data: (conversations) {
          if (conversations.isEmpty) return const _EmptyInbox();

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: conversations.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              indent: 84,
              color: Colors.grey.shade200,
            ),
            itemBuilder: (context, index) =>
                _ConversationTile(conversation: conversations[index]),
          );
        },
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum_outlined, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('Nenhuma conversa por aqui',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: InkFlowColors.primary)),
          const SizedBox(height: 8),
          const Text('Encontre um tatuador e inicie um orçamento.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => context.go('/search'),
            style: ElevatedButton.styleFrom(
              backgroundColor: InkFlowColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Explorar Tatuadores'),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;

  const _ConversationTile({required this.conversation});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: AvatarImage(url: conversation.contactAvatarUrl, size: 48),
      title: Text(
        conversation.contactName,
        style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: InkFlowColors.primary),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          conversation.preview,
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      trailing: Text(
        conversation.timeLabel(),
        style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
      ),
      onTap: () => context.push('/chat?contactId=${conversation.contactId}'),
    );
  }
}
