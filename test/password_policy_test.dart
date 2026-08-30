import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/core/utils/password_policy.dart';

void main() {
  group('PasswordPolicy', () {
    test('aceita senha com letra, número e comprimento mínimo', () {
      expect(PasswordPolicy.isValid('inkflow2026'), isTrue);
    });

    test('rejeita senha curta', () {
      expect(PasswordPolicy.validate('ink1'),
          'A senha deve ter no mínimo 8 caracteres');
    });

    test('rejeita senha só com números', () {
      expect(PasswordPolicy.validate('12345678'),
          'A senha deve conter ao menos uma letra');
    });

    test('rejeita senha só com letras', () {
      expect(PasswordPolicy.validate('inkflowapp'),
          'A senha deve conter ao menos um número');
    });

    test('rejeita vazio e null', () {
      expect(PasswordPolicy.validate(''), 'A senha é obrigatória');
      expect(PasswordPolicy.validate(null), 'A senha é obrigatória');
    });
  });
}
