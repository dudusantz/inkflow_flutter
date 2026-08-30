import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/core/errors/error_utils.dart';

void main() {
  group('userFriendlyErrorMessage', () {
    test('retorna mensagem de rede para SocketException', () {
      expect(
        userFriendlyErrorMessage(Exception('SocketException: failed host lookup')),
        contains('internet'),
      );
    });

    test('retorna mensagem genérica para erros desconhecidos', () {
      expect(
        userFriendlyErrorMessage(Exception('algo estranho')),
        'Ocorreu um erro inesperado. Tente novamente.',
      );
    });
  });
}
