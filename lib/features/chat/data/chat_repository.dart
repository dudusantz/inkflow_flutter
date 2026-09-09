import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:inkflow/core/data/supabase_providers.dart';
import 'package:inkflow/features/chat/domain/chat_message.dart';

class ChatRepository {
  final SupabaseClient _supabase;

  ChatRepository(this._supabase);

  String? get _myId => _supabase.auth.currentUser?.id;

  /// Chave da conversa, igual a coluna gerada `messages.conversation_key`.
  static String conversationKey(String a, String b) {
    final ids = [a, b]..sort();
    return '${ids.first}:${ids.last}';
  }

  /// Mensagens da conversa, em tempo real e em ordem decrescente (a lista da
  /// tela usa `reverse: true`).
  ///
  /// O filtro roda no servidor via `conversation_key`. A versao anterior
  /// assinava a tabela `messages` inteira e descartava o que nao interessava em
  /// Dart, o que entregava as conversas de todos os usuarios ao dispositivo.
  Stream<List<ChatMessage>> watchConversation(String otherUserId) {
    final myId = _myId;
    if (myId == null) return Stream.value(const []);

    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_key', conversationKey(myId, otherUserId))
        .order('created_at', ascending: false)
        .asyncMap((rows) async {
          final messages = rows
              .map((row) => ChatMessage.fromRow(row, myId))
              .toList(growable: false);
          return Future.wait(messages.map(_signAttachment));
        });
  }

  /// Ultima mensagem de cada conversa do usuario logado.
  ///
  /// O stream e limitado pelas policies de `messages` (so chegam mensagens em
  /// que o usuario e remetente ou destinatario), e os nomes vem da view
  /// `chat_directory`, que so revela contatos com historico em comum.
  Stream<List<Conversation>> watchInbox() {
    final myId = _myId;
    if (myId == null) return Stream.value(const []);

    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .asyncMap((rows) => _groupIntoConversations(rows, myId));
  }

  /// Carga inicial determinística da caixa de entrada.
  ///
  /// O canal Realtime pode demorar para emitir o primeiro snapshot em alguns
  /// navegadores. Esta consulta REST evita que a tela permaneça carregando
  /// indefinidamente antes de mostrar as conversas existentes.
  Future<List<Conversation>> fetchInbox() async {
    final myId = _myId;
    if (myId == null) return const [];

    final rows = await _supabase
        .from('messages')
        .select()
        .order('created_at', ascending: false)
        .timeout(const Duration(seconds: 10));

    return _groupIntoConversations(
      List<Map<String, dynamic>>.from(rows),
      myId,
      resolveContacts: true,
    );
  }

  /// Nome e avatar do interlocutor.
  ///
  /// Procura primeiro entre os contatos com historico (`chat_directory`) e,
  /// para uma conversa que ainda nao existe, cai na vitrine publica de
  /// tatuadores. Devolve `null` quando o usuario nao pode ver aquele contato.
  Future<ChatContact?> fetchContact(String contactId) async {
    for (final source in const ['chat_directory', 'artist_directory']) {
      try {
        final row = await _supabase
            .from(source)
            .select('id, name, avatar_url')
            .eq('id', contactId)
            .maybeSingle()
            .timeout(const Duration(seconds: 10));

        if (row != null) {
          return ChatContact.fromRow(Map<String, dynamic>.from(row));
        }
      } on PostgrestException catch (error) {
        // Projetos antigos podem ainda não ter a view de contatos. Nesse caso
        // a vitrine pública continua sendo uma fonte válida para tatuadores.
        if (error.code != 'PGRST205' && error.code != '42P01') rethrow;
      }
    }
    return null;
  }

  Future<void> sendMessage({
    required String receiverId,
    required String content,
  }) async {
    final myId = _myId;
    if (myId == null) {
      throw const AuthException('Sessão expirada. Entre novamente.');
    }

    await _supabase.from('messages').insert({
      'sender_id': myId,
      'receiver_id': receiverId,
      'content': content,
    });
  }

  Future<void> sendAttachment({
    required String receiverId,
    required Uint8List bytes,
    required String type,
    required String fileName,
    required String contentType,
    int? durationSeconds,
  }) async {
    final myId = _myId;
    if (myId == null) {
      throw const AuthException('Sessão expirada. Entre novamente.');
    }

    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path =
        '$myId/${conversationKey(myId, receiverId)}/${DateTime.now().microsecondsSinceEpoch}_$safeName';

    await _supabase.storage.from('chat-media').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType),
        );

    try {
      await _supabase.from('messages').insert({
        'sender_id': myId,
        'receiver_id': receiverId,
        'content': '',
        'attachment_path': path,
        'attachment_type': type,
        'attachment_name': fileName,
        'duration_seconds': durationSeconds,
      });
    } catch (_) {
      await _supabase.storage.from('chat-media').remove([path]);
      rethrow;
    }
  }

  Future<ChatMessage> _signAttachment(ChatMessage message) async {
    final path = message.attachmentPath;
    if (path == null) return message;
    final url = await _supabase.storage
        .from('chat-media')
        .createSignedUrl(path, 60 * 60);
    return message.withAttachmentUrl(url);
  }

  Future<List<Conversation>> _groupIntoConversations(
    List<Map<String, dynamic>> rows,
    String myId, {
    bool resolveContacts = true,
  }) async {
    final byContact = <String, Conversation>{};

    for (final row in rows) {
      final message = ChatMessage.fromRow(row, myId);
      final contactId = message.isMine ? message.receiverId : message.senderId;

      // `rows` ja vem ordenado do mais recente para o mais antigo, entao a
      // primeira ocorrencia de cada contato e a ultima mensagem da conversa.
      byContact.putIfAbsent(
        contactId,
        () => Conversation(
          contactId: contactId,
          contactName: 'Usuário',
          lastMessage: message.content.isNotEmpty
              ? message.content
              : switch (message.attachmentType) {
                  'image' => '📷 Foto',
                  'video' => '🎬 Vídeo',
                  'audio' => '🎤 Áudio',
                  _ => 'Anexo',
                },
          lastMessageAt: message.createdAt,
          lastMessageIsMine: message.isMine,
        ),
      );
    }

    if (byContact.isEmpty) return const [];

    if (resolveContacts) {
      try {
        final contacts = await _supabase
            .from('chat_directory')
            .select('id, name, avatar_url')
            .inFilter('id', byContact.keys.toList())
            .timeout(const Duration(seconds: 6));

        for (final contact in contacts) {
          final id = contact['id'].toString();
          final existing = byContact[id];
          if (existing == null) continue;

          byContact[id] = existing.copyWith(
            contactName: contact['name']?.toString(),
            contactAvatarUrl: contact['avatar_url']?.toString(),
          );
        }
      } catch (_) {
        // Nome e avatar são complementares. Uma falha na view de contatos não
        // pode impedir que as conversas já carregadas sejam exibidas.
      }
    }

    return byContact.values.toList()
      ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(supabaseClientProvider));
});
