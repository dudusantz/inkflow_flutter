import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inkflow/core/theme/app_theme.dart';

// --- PROVIDER DE INBOX EM TEMPO REAL ---
final inboxStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final supabase = Supabase.instance.client;
  final myId = supabase.auth.currentUser?.id;

  if (myId == null) return Stream.value([]);

  return supabase
      .from('messages')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .asyncMap((messages) async {
        // 1. Filtra apenas as mensagens que envolvem o usuário logado
        final myMessages = messages
            .where((m) => m['sender_id'] == myId || m['receiver_id'] == myId)
            .toList();

        // 2. Agrupa pela última mensagem de cada conversa
        final Map<String, Map<String, dynamic>> conversations = {};

        for (var msg in myMessages) {
          final otherId =
              msg['sender_id'] == myId ? msg['receiver_id'] : msg['sender_id'];

          if (!conversations.containsKey(otherId)) {
            final createdAt =
                DateTime.tryParse(msg['created_at'].toString())?.toLocal() ??
                    DateTime.now();
            final isToday = createdAt.day == DateTime.now().day &&
                createdAt.month == DateTime.now().month &&
                createdAt.year == DateTime.now().year;

            final timeString = isToday
                ? '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}'
                : '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}';

            conversations[otherId] = {
              'id': otherId,
              'lastMessage': msg['sender_id'] == myId
                  ? 'Você: ${msg['content']}'
                  : msg['content'],
              'time': timeString,
              'unreadCount': 0, // Funcionalidade futura
              'isOnline': true, // Mock de UI
            };
          }
        }

        if (conversations.isEmpty) return [];

        // 3. Busca os nomes e fotos reais das pessoas na tabela de perfis
        final uniqueIds = conversations.keys.toList();
        try {
          final profiles = await supabase
              .from('profiles')
              .select('id, name, avatar_url')
              .inFilter('id', uniqueIds);

          for (var p in profiles) {
            final id = p['id'].toString();
            if (conversations.containsKey(id)) {
              conversations[id]!['name'] = p['name'] ?? 'Usuário';
              conversations[id]!['avatar'] = p['avatar_url'] ??
                  'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100&h=100&fit=crop';
            }
          }
        } catch (e) {
          debugPrint('Erro ao buscar perfis na inbox: $e');
        }
        // 4. Fallback caso a pessoa não tenha foto no perfil
        for (var conv in conversations.values) {
          conv['name'] ??= 'Usuário Desconhecido';
          conv['avatar'] ??=
              'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100&h=100&fit=crop';
        }

        return conversations.values.toList();
      });
});

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final inboxAsync = ref.watch(inboxStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: inboxAsync.when(
              loading: () => const Center(
                  child:
                      CircularProgressIndicator(color: InkFlowColors.accent)),
              error: (e, s) =>
                  Center(child: Text('Erro ao carregar mensagens: $e')),
              data: (chats) {
                // Filtro local pela barra de pesquisa
                final filteredChats = chats.where((c) {
                  final name = c['name'].toString().toLowerCase();
                  return name.contains(_searchQuery.toLowerCase());
                }).toList();

                if (chats.isEmpty) return _buildEmptyState();
                if (filteredChats.isEmpty)
                  return const Center(
                      child: Text('Nenhuma conversa encontrada.'));

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filteredChats.length,
                  separatorBuilder: (context, index) => Divider(
                      color: Colors.grey.shade200, height: 1, indent: 76),
                  itemBuilder: (context, index) {
                    return _buildChatTile(context, filteredChats[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: InkFlowColors.primary,
      elevation: 0,
      centerTitle: true,
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
      title: const Text(
        'Mensagens',
        style: TextStyle(
            color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: InputDecoration(
            hintText: 'Buscar nas conversas...',
            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            prefixIcon:
                Icon(Icons.search, color: Colors.grey.shade500, size: 20),
            prefixIconConstraints: const BoxConstraints(minWidth: 32),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildChatTile(BuildContext context, Map<String, dynamic> chat) {
    final bool hasUnread = chat['unreadCount'] > 0;

    return InkWell(
      onTap: () => context.push('/chat?artistId=${chat['id']}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundImage: NetworkImage(chat['avatar']),
                  backgroundColor: Colors.grey.shade200,
                ),
                if (chat['isOnline'] == true)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chat['name'],
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                      color: InkFlowColors.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    chat['lastMessage'],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          hasUnread ? FontWeight.bold : FontWeight.normal,
                      color: hasUnread
                          ? InkFlowColors.primary
                          : Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  chat['time'],
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        hasUnread ? InkFlowColors.accent : Colors.grey.shade500,
                    fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 6),
                if (hasUnread)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                        color: InkFlowColors.accent, shape: BoxShape.circle),
                    child: Text(
                      '${chat['unreadCount']}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  )
                else
                  const SizedBox(height: 22),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: Colors.grey.shade100, shape: BoxShape.circle),
            child: Icon(Icons.chat_bubble_outline_rounded,
                size: 48, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 20),
          const Text(
            'Nenhuma mensagem ainda',
            style: TextStyle(
                color: Color(0xFF4B5563),
                fontSize: 16,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Suas conversas com estúdios\naparecerão aqui.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
          ),
        ],
      ),
    );
  }
}
