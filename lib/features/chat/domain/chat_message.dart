import 'dart:convert';

bool isFutureProposalSchedule(
        DateTime date, int hour, int minute, DateTime now) =>
    DateTime(date.year, date.month, date.day, hour, minute).isAfter(now);

/// Mensagem de uma conversa entre dois usuarios.
class ChatMessage {
  static const proposalPrefix = '[INKFLOW_PROPOSAL]';
  static const proposalCancellationPrefix = '[INKFLOW_PROPOSAL_CANCELLED]';
  static const proposalAcceptancePrefix = '[INKFLOW_PROPOSAL_ACCEPTED]';
  static const proposalRejectionPrefix = '[INKFLOW_PROPOSAL_REJECTED]';
  static const proposalPending = 'pending';
  static const proposalAccepted = 'accepted';
  static const proposalRejected = 'rejected';
  static const proposalCancelled = 'cancelled';
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

  Map<String, dynamic>? get proposal {
    if (!content.startsWith(proposalPrefix)) return null;
    try {
      return Map<String, dynamic>.from(
        jsonDecode(content.substring(proposalPrefix.length)) as Map,
      );
    } catch (_) {
      return null;
    }
  }

  bool get isProposal => proposal != null;

  String? get cancelledProposalId =>
      content.startsWith(proposalCancellationPrefix) &&
              content.length > proposalCancellationPrefix.length
          ? content.substring(proposalCancellationPrefix.length)
          : null;

  String? get acceptedProposalId =>
      content.startsWith(proposalAcceptancePrefix) &&
              content.length > proposalAcceptancePrefix.length
          ? content.substring(proposalAcceptancePrefix.length)
          : null;

  String? get rejectedProposalId =>
      content.startsWith(proposalRejectionPrefix) &&
              content.length > proposalRejectionPrefix.length
          ? content.substring(proposalRejectionPrefix.length)
          : null;

  String? get proposalEventId =>
      cancelledProposalId ?? acceptedProposalId ?? rejectedProposalId;

  String? get proposalEventStatus => cancelledProposalId != null
      ? proposalCancelled
      : acceptedProposalId != null
          ? proposalAccepted
          : rejectedProposalId != null
              ? proposalRejected
              : null;

  String get previewText => proposalEventStatus == proposalCancelled
      ? 'Proposta cancelada'
      : proposalEventStatus == proposalAccepted
          ? 'Proposta aceita'
          : proposalEventStatus == proposalRejected
              ? 'Proposta recusada'
              : isProposal
                  ? '📋 Proposta enviada'
                  : content;

  static String encodeProposal(Map<String, dynamic> values) =>
      '$proposalPrefix${jsonEncode(values)}';

  static String encodeProposalCancellation(String proposalId) =>
      '$proposalCancellationPrefix$proposalId';

  static String encodeProposalResponse(String proposalId,
          {required bool accepted}) =>
      '${accepted ? proposalAcceptancePrefix : proposalRejectionPrefix}$proposalId';

  String get timeLabel => '${createdAt.hour.toString().padLeft(2, '0')}:'
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

  String get preview => lastMessageIsMine ? 'Você: $lastMessage' : lastMessage;

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
