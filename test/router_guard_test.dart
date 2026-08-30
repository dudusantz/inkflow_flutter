import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/router.dart';

void main() {
  group('authRedirect', () {
    test('manda visitante para o login em rota protegida', () {
      expect(
        authRedirect(isAuthenticated: false, location: '/schedule'),
        '/',
      );
      expect(authRedirect(isAuthenticated: false, location: '/profile'), '/');
    });

    test('deixa visitante nas rotas públicas', () {
      expect(authRedirect(isAuthenticated: false, location: '/'), isNull);
      expect(
        authRedirect(isAuthenticated: false, location: '/register'),
        isNull,
      );
      expect(
        authRedirect(isAuthenticated: false, location: '/callback'),
        isNull,
      );
    });

    test('tira usuário logado das telas de login e cadastro', () {
      expect(authRedirect(isAuthenticated: true, location: '/'), '/home');
      expect(
        authRedirect(isAuthenticated: true, location: '/register'),
        '/home',
      );
    });

    test('não interfere em rota protegida com sessão ativa', () {
      expect(
        authRedirect(isAuthenticated: true, location: '/schedule'),
        isNull,
      );
    });

    test('mantém o retorno da confirmação visível com sessão ativa', () {
      expect(
        authRedirect(isAuthenticated: true, location: '/callback'),
        isNull,
      );
    });
  });

  group('chatContactIdOf', () {
    test('lê contactId', () {
      expect(chatContactIdOf(Uri.parse('/chat?contactId=abc')), 'abc');
    });

    test('aceita artistId como alias legado', () {
      expect(chatContactIdOf(Uri.parse('/chat?artistId=abc')), 'abc');
    });

    test('devolve null sem parâmetro, para o router mandar à inbox', () {
      // O fallback anterior era `?? '1'`, que não é UUID e fazia o insert da
      // mensagem falhar no banco.
      expect(chatContactIdOf(Uri.parse('/chat')), isNull);
      expect(chatContactIdOf(Uri.parse('/chat?contactId=')), isNull);
      expect(chatContactIdOf(Uri.parse('/chat?contactId=%20')), isNull);
    });
  });
}
