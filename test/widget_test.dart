import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/auth/data/auth_repository.dart';

void main() {
  test('widget_test reexporta suite de auth', () {
    expect(
      AuthRepository.parseDuplicateField(Exception('User already registered')),
      DuplicateRegistrationField.email,
    );
  });
}
