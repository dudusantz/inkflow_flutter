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
