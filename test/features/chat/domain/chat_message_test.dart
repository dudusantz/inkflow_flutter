import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/chat/domain/chat_message.dart';

void main() {
  test('codifica e identifica uma proposta no chat', () {
    final content = ChatMessage.encodeProposal({
      'service': 'Tatuagem autoral',
      'amount': 450.0,
      'date': '2026-10-10T00:00:00.000',
      'notes': 'Inclui uma sessão.',
    });
    final message = ChatMessage(
      id: '1',
      senderId: 'artist',
      receiverId: 'client',
      content: content,
      createdAt: DateTime(2026, 9, 17),
      isMine: true,
    );

    expect(message.isProposal, isTrue);
    expect(message.proposal?['service'], 'Tatuagem autoral');
    expect(message.proposal?['amount'], 450.0);
    expect(message.previewText, '📋 Proposta enviada');
  });
}
