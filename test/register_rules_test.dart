import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/auth/presentation/register_screen.dart';

/// Regras do RF01 (cadastro). São a porta de entrada do app e não tinham
/// nenhum teste.
void main() {
  group('CpfValidator', () {
    test('aceita CPF válido com e sem máscara', () {
      expect(CpfValidator.isValid('529.982.247-25'), isTrue);
      expect(CpfValidator.isValid('52998224725'), isTrue);
    });

    test('rejeita dígito verificador incorreto', () {
      expect(CpfValidator.isValid('529.982.247-24'), isFalse);
    });

    test('rejeita sequência de dígitos repetidos', () {
      expect(CpfValidator.isValid('111.111.111-11'), isFalse);
      expect(CpfValidator.isValid('00000000000'), isFalse);
    });

    test('rejeita comprimento diferente de 11', () {
      expect(CpfValidator.isValid('5299822472'), isFalse);
      expect(CpfValidator.isValid(''), isFalse);
    });
  });

  group('AgeCalculator', () {
    final today = DateTime.now();

    test('identifica menor de idade', () {
      final birth = DateTime(today.year - 17, today.month, today.day);
      expect(birth.age, 17);
    });

    test('não conta o ano quando o aniversário ainda não chegou', () {
      // Faz 18 anos amanhã: hoje ainda é menor.
      final tomorrow = today.add(const Duration(days: 1));
      final birth =
          DateTime(tomorrow.year - 18, tomorrow.month, tomorrow.day);
      expect(birth.age, 17);
    });

    test('conta o ano no dia exato do aniversário', () {
      final birth = DateTime(today.year - 18, today.month, today.day);
      expect(birth.age, 18);
    });
  });
}
