import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/auth/data/auth_repository.dart';

void main() {
  group('AuthRepository.parseDuplicateField', () {
    test('identifica e-mail já cadastrado', () {
      expect(
        AuthRepository.parseDuplicateField(
          Exception('User already registered'),
        ),
        DuplicateRegistrationField.email,
      );
    });

    test('identifica CPF duplicado na constraint', () {
      expect(
        AuthRepository.parseDuplicateField(
          Exception(
            'duplicate key value violates unique constraint "profiles_cpf_key"',
          ),
        ),
        DuplicateRegistrationField.cpf,
      );
    });

    test('identifica o erro levantado pelo trigger handle_new_user', () {
      expect(
        AuthRepository.parseDuplicateField(
          Exception('cpf_already_registered'),
        ),
        DuplicateRegistrationField.cpf,
      );
    });

    test('trata o erro genérico do GoTrue no cadastro como CPF duplicado', () {
      // O GoTrue mascara exceções do trigger; a única restrição que ele pode
      // violar no cadastro é o índice único de CPF.
      expect(
        AuthRepository.parseDuplicateField(
          Exception('Database error saving new user'),
        ),
        DuplicateRegistrationField.cpf,
      );
    });

    test('retorna null para erro genérico', () {
      expect(
        AuthRepository.parseDuplicateField(Exception('network error')),
        isNull,
      );
    });
  });

  group('AuthRepository.isRateLimitError', () {
    test('identifica HTTP 429', () {
      expect(
        AuthRepository.isRateLimitError(Exception('429 Too Many Requests')),
        isTrue,
      );
    });
  });
}
