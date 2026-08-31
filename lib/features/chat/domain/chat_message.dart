/// Mensagem de uma conversa entre dois usuarios.
class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime createdAt;
  final bool isMine;
  final String? attachmentPath;
  final String? attachmentUrl;
  final String? attachmentType;
  final String? attachmentName;
  final int? durationSeconds;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.createdAt,
    required this.isMine,
    this.attachmentPath,
    this.attachmentUrl,
    this.attachmentType,
    this.attachmentName,
    this.durationSeconds,
  });

  factory ChatMessage.fromRow(Map<String, dynamic> row, String currentUserId) {
    final senderId = row['sender_id'].toString();
    return ChatMessage(
      id: row['id'].toString(),
      senderId: senderId,
      receiverId: row['receiver_id'].toString(),
      content: row['content']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
      isMine: senderId == currentUserId,
      attachmentPath: row['attachment_path']?.toString(),
      attachmentType: row['attachment_type']?.toString(),
      attachmentName: row['attachment_name']?.toString(),
      durationSeconds: int.tryParse(row['duration_seconds']?.toString() ?? ''),
    );
  }

  ChatMessage withAttachmentUrl(String url) => ChatMessage(
        id: id,
        senderId: senderId,
        receiverId: receiverId,
        content: content,
        createdAt: createdAt,
        isMine: isMine,
        attachmentPath: attachmentPath,
        attachmentUrl: url,
        attachmentType: attachmentType,
        attachmentName: attachmentName,
        durationSeconds: durationSeconds,
      );

  bool get hasAttachment => attachmentPath != null;

  String get timeLabel =>
      '${createdAt.hour.toString().padLeft(2, '0')}:'
      '${createdAt.minute.toString().padLeft(2, '0')}';
}

/// Identificacao minima do interlocutor, para o cabecalho do chat.
class ChatContact {
  final String id;
  final String name;
  final String? avatarUrl;

  const ChatContact({
    required this.id,
    required this.name,
    this.avatarUrl,
  });

  factory ChatContact.fromRow(Map<String, dynamic> row) {
    final name = row['name']?.toString().trim();
    return ChatContact(
      id: row['id'].toString(),
      name: (name == null || name.isEmpty) ? 'Usuário' : name,
      avatarUrl: row['avatar_url']?.toString(),
    );
  }
}

/// Ultima mensagem de cada conversa, para a listagem da inbox.
class Conversation {
  final String contactId;
  final String contactName;
  final String? contactAvatarUrl;
  final String lastMessage;
  final DateTime lastMessageAt;
  final bool lastMessageIsMine;

  const Conversation({
    required this.contactId,
    required this.contactName,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.lastMessageIsMine,
    this.contactAvatarUrl,
  });

  Conversation copyWith({String? contactName, String? contactAvatarUrl}) {
    return Conversation(
      contactId: contactId,
      contactName: contactName ?? this.contactName,
      contactAvatarUrl: contactAvatarUrl ?? this.contactAvatarUrl,
      lastMessage: lastMessage,
      lastMessageAt: lastMessageAt,
      lastMessageIsMine: lastMessageIsMine,
    );
  }

  String get preview =>
      lastMessageIsMine ? 'Você: $lastMessage' : lastMessage;

  /// Hora para conversas de hoje, data curta para as anteriores.
  String timeLabel({DateTime? now}) {
    final reference = now ?? DateTime.now();
    final isToday = lastMessageAt.year == reference.year &&
        lastMessageAt.month == reference.month &&
        lastMessageAt.day == reference.day;

    if (isToday) {
      return '${lastMessageAt.hour.toString().padLeft(2, '0')}:'
          '${lastMessageAt.minute.toString().padLeft(2, '0')}';
    }
    return '${lastMessageAt.day.toString().padLeft(2, '0')}/'
        '${lastMessageAt.month.toString().padLeft(2, '0')}';
  }
}
