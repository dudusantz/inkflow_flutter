import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:inkflow/core/errors/error_utils.dart';
import 'package:inkflow/core/theme/app_theme.dart';
import 'package:inkflow/core/widgets/shared_widgets.dart';
import 'package:inkflow/features/chat/data/chat_repository.dart';
import 'package:inkflow/features/chat/domain/chat_message.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  List<Conversation>? _conversations;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _loadInbox();
  }

  Future<void> _loadInbox() async {
    final shouldRebuild = _conversations != null || _loadError != null;
    _conversations = null;
    _loadError = null;
    if (shouldRebuild && mounted) setState(() {});
    try {
      final conversations =
          await ref.read(chatRepositoryProvider).fetchInbox();
      if (!mounted) return;
      setState(() => _conversations = conversations);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InkFlowColors.background,
      appBar: AppBar(
        backgroundColor: InkFlowColors.primary,
        automaticallyImplyLeading: false,
        toolbarHeight: 88,
        titleSpacing: 20,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mensagens',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800)),
            SizedBox(height: 4),
            Text('Conversas com seus tatuadores e clientes',
                style: TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Buscar conversa...',
                prefixIcon: const Icon(Icons.search_rounded,
                    color: InkFlowColors.accentDark),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: InkFlowColors.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(
                        color: InkFlowColors.accent, width: 1.5)),
              ),
            ),
          ),
          Expanded(
            child: _buildInboxContent(),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }

  Widget _buildInboxContent() {
    final error = _loadError;
    if (error != null) {
      return AsyncErrorView(
        error: error,
        customMessage: 'Erro ao carregar as conversas.',
        onRetry: _loadInbox,
      );
    }

    final conversations = _conversations;
    if (conversations == null) return const _InboxLoading();
    if (conversations.isEmpty) return const _EmptyInbox();

    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? conversations
        : conversations
            .where((item) =>
                item.contactName.toLowerCase().contains(query) ||
                item.lastMessage.toLowerCase().contains(query))
            .toList();
    if (filtered.isEmpty) return const _NoSearchResults();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
      itemCount: filtered.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
            child: Row(
              children: [
                Text(
                  query.isEmpty
                      ? 'Conversas recentes'
                      : '${filtered.length} resultado(s)',
                  style: const TextStyle(
                      color: InkFlowColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text('${conversations.length} conversa(s)',
                    style: const TextStyle(
                        color: InkFlowColors.textMuted, fontSize: 11)),
              ],
            ),
          );
        }
        final conversation = filtered[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SizedBox(
            height: 86,
            child: _ConversationCard(
              key: ValueKey(conversation.contactId),
              conversation: conversation,
            ),
          ),
        );
      },
    );
  }
}

class _InboxLoading extends StatelessWidget {
  const _InboxLoading();

  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => Container(
          height: 86,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(
                  color: Color(0xFFE2E8F0),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 130,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 9,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                    color: Color(0xFFE5F7F6), shape: BoxShape.circle),
                child: const Icon(Icons.forum_outlined,
                    size: 40, color: InkFlowColors.accentDark),
              ),
              const SizedBox(height: 22),
              const Text('Suas conversas aparecerão aqui',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: InkFlowColors.primary)),
              const SizedBox(height: 8),
              const Text(
                  'Explore perfis, encontre o profissional ideal e comece uma conversa.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: InkFlowColors.textMuted,
                      fontSize: 13,
                      height: 1.45)),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/search'),
                style: FilledButton.styleFrom(
                    backgroundColor: InkFlowColors.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 14)),
                icon: const Icon(Icons.explore_outlined),
                label: const Text('Explorar tatuadores'),
              ),
            ],
          ),
        ),
      );
}

class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults();

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 46, color: InkFlowColors.textMuted),
            SizedBox(height: 12),
            Text('Nenhuma conversa encontrada',
                style: TextStyle(
                    color: InkFlowColors.primary, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _ConversationCard extends StatelessWidget {
  final Conversation conversation;
  const _ConversationCard({super.key, required this.conversation});

  @override
  Widget build(BuildContext context) {
    final attachmentIcon = switch (conversation.lastMessage) {
      '📷 Foto' => Icons.image_outlined,
      '🎬 Vídeo' => Icons.videocam_outlined,
      '🎤 Áudio' => Icons.mic_none_rounded,
      _ => null,
    };
    final cleanLastMessage = conversation.lastMessage
        .replaceFirst('📷 ', '')
        .replaceFirst('🎬 ', '')
        .replaceFirst('🎤 ', '');
    final previewText = conversation.lastMessageIsMine
        ? 'Você: $cleanLastMessage'
        : cleanLastMessage;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => context.push('/chat?contactId=${conversation.contactId}'),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: InkFlowColors.border)),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AvatarImage(url: conversation.contactAvatarUrl, size: 54),
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 15,
                      height: 15,
                      decoration: BoxDecoration(
                          color: InkFlowColors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2)),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(conversation.contactName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: InkFlowColors.primary)),
                        ),
                        Text(conversation.timeLabel(),
                            style: const TextStyle(
                                color: InkFlowColors.textMuted, fontSize: 10)),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        if (attachmentIcon != null) ...[
                          Icon(attachmentIcon,
                              size: 16, color: InkFlowColors.accentDark),
                          const SizedBox(width: 5),
                        ],
                        Expanded(
                          child: Text(
                            previewText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: InkFlowColors.textMuted, fontSize: 12),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: Color(0xFFCBD5E1), size: 20),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
