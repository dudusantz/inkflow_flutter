import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/chat/domain/chat_message.dart';

void main() {
  test('usa o instante gravado e interpreta horários legados em São Paulo', () {
    final legacy = {'date': '2026-11-17', 'time': '18:56:30'};
    expect(proposalStartAt(legacy)?.toUtc(),
        DateTime.utc(2026, 11, 17, 21, 56, 30));
    expect(
      proposalStartAt({...legacy, 'startsAt': '2026-11-16T21:56:00Z'}),
      DateTime.utc(2026, 11, 16, 21, 56),
    );
    expect(proposalStartAt({...legacy, 'time': '27:00'}), isNull);
  });

  test('proposta só aceita data e horário futuros', () {
    final now = DateTime(2026, 9, 26, 15, 30);
    expect(isFutureProposalSchedule(now, 15, 29, now), isFalse);
    expect(isFutureProposalSchedule(now, 15, 30, now), isFalse);
    expect(isFutureProposalSchedule(now, 15, 31, now), isTrue);
    expect(isFutureProposalSchedule(DateTime(2026, 9, 27), 9, 0, now), isTrue);
  });

  test('cancelamento referencia a proposta e aparece na prévia', () {
    final message = ChatMessage(
      id: 'cancel-1',
      senderId: 'artist',
      receiverId: 'client',
      content: ChatMessage.encodeProposalCancellation('proposal-1'),
      createdAt: DateTime(2026, 9, 26),
      isMine: true,
    );

    expect(message.cancelledProposalId, 'proposal-1');
    expect(message.previewText, 'Proposta cancelada');
    expect(message.isProposal, isFalse);
  });

  test('aceite e recusa referenciam a proposta e aparecem na prévia', () {
    ChatMessage response(bool accepted) => ChatMessage(
          id: accepted ? 'accept-1' : 'reject-1',
          senderId: 'client',
          receiverId: 'artist',
          content: ChatMessage.encodeProposalResponse(
            'proposal-1',
            accepted: accepted,
          ),
          createdAt: DateTime(2026, 9, 26),
          isMine: true,
        );

    expect(response(true).proposalEventId, 'proposal-1');
    expect(response(true).proposalEventStatus, ChatMessage.proposalAccepted);
    expect(response(true).previewText, 'Proposta aceita');
    expect(response(false).proposalEventId, 'proposal-1');
    expect(response(false).proposalEventStatus, ChatMessage.proposalRejected);
    expect(response(false).previewText, 'Proposta recusada');
  });

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
    expect(message.previewText, 'Proposta enviada');
    final received = ChatMessage(
      id: message.id,
      senderId: message.senderId,
      receiverId: message.receiverId,
      content: content,
      createdAt: message.createdAt,
      isMine: false,
    );
    expect(received.previewText, 'Proposta recebida');
  });
}
