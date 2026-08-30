import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/chat/data/chat_repository.dart';
import 'package:inkflow/features/chat/domain/chat_message.dart';

void main() {
  group('ChatRepository.conversationKey', () {
    test('é a mesma para os dois participantes', () {
      // Precisa bater com a coluna gerada `messages.conversation_key`, senão o
      // filtro server-side do stream não encontra nada.
      expect(
        ChatRepository.conversationKey('bbb', 'aaa'),
        ChatRepository.conversationKey('aaa', 'bbb'),
      );
      expect(ChatRepository.conversationKey('aaa', 'bbb'), 'aaa:bbb');
    });

    test('difere entre conversas distintas', () {
      expect(
        ChatRepository.conversationKey('aaa', 'bbb'),
        isNot(ChatRepository.conversationKey('aaa', 'ccc')),
      );
    });
  });

  group('ChatMessage.fromRow', () {
    test('marca como minha a mensagem que eu enviei', () {
      final message = ChatMessage.fromRow({
        'id': 'm1',
        'sender_id': 'me',
        'receiver_id': 'you',
        'content': 'Olá',
        'created_at': '2026-08-20T09:05:00Z',
      }, 'me');

      expect(message.isMine, isTrue);
      expect(message.content, 'Olá');
    });

    test('marca como do outro a mensagem recebida', () {
      final message = ChatMessage.fromRow({
        'id': 'm1',
        'sender_id': 'you',
        'receiver_id': 'me',
        'content': 'Oi',
        'created_at': '2026-08-20T09:05:00Z',
      }, 'me');

      expect(message.isMine, isFalse);
    });
  });

  group('Conversation', () {
    Conversation conversation({
      required DateTime at,
      bool mine = false,
    }) {
      return Conversation(
        contactId: 'c1',
        contactName: 'Ana',
        lastMessage: 'Fechado!',
        lastMessageAt: at,
        lastMessageIsMine: mine,
      );
    }

    test('prefixa o preview quando a última mensagem é minha', () {
      expect(
        conversation(at: DateTime(2026, 8, 20, 9), mine: true).preview,
        'Você: Fechado!',
      );
      expect(
        conversation(at: DateTime(2026, 8, 20, 9)).preview,
        'Fechado!',
      );
    });

    test('mostra hora hoje e data nos dias anteriores', () {
      final now = DateTime(2026, 8, 20, 18);

      expect(
        conversation(at: DateTime(2026, 8, 20, 9, 5)).timeLabel(now: now),
        '09:05',
      );
      expect(
        conversation(at: DateTime(2026, 8, 19, 9, 5)).timeLabel(now: now),
        '19/08',
      );
    });
  });

  group('ChatContact.fromRow', () {
    test('usa fallback quando o nome vem vazio', () {
      final contact = ChatContact.fromRow({'id': 'c1', 'name': '  '});
      expect(contact.name, 'Usuário');
    });
  });
}
