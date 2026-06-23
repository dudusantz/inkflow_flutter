import 'package:supabase_flutter/supabase_flutter.dart';

enum DuplicateRegistrationField { email, cpf }

class DuplicateRegistrationException implements Exception {
  final DuplicateRegistrationField field;

  const DuplicateRegistrationException(this.field);
}

class AuthRateLimitException implements Exception {
  const AuthRateLimitException();
}

class AuthRepository {
  final SupabaseClient _supabase;

  AuthRepository(this._supabase);

  // Observa mudanças no estado de autenticação (Login, Logout, Token Expirado)
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // Obtém o utilizador atual (se estiver logado)
  User? get currentUser => _supabase.auth.currentUser;

  // Função de Login
  Future<AuthResponse> signIn(String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<bool> isCpfRegistered(String cpf) async {
    final result = await _supabase
        .from('profiles')
        .select('id')
        .eq('cpf', cpf)
        .maybeSingle();
    return result != null;
  }

  static DuplicateRegistrationField? parseDuplicateField(Object error) {
    final message = error.toString().toLowerCase();

    if (message.contains('duplicate') &&
        (message.contains('cpf') || message.contains('profiles_cpf'))) {
      return DuplicateRegistrationField.cpf;
    }

    if (message.contains('user already registered') ||
        message.contains('already registered') ||
        message.contains('email address is already') ||
        (message.contains('duplicate') && message.contains('email'))) {
      return DuplicateRegistrationField.email;
    }

    if (message.contains('duplicate key') && message.contains('cpf')) {
      return DuplicateRegistrationField.cpf;
    }

    return null;
  }

  static bool isRateLimitError(Object error) {
    if (error is AuthRateLimitException) return true;

    if (error is AuthException) {
      final code = error.statusCode?.toString();
      final message = error.message.toLowerCase();
      return code == '429' ||
          message.contains('too many') ||
          message.contains('rate limit');
    }

    final text = error.toString().toLowerCase();
    return text.contains('429') ||
        text.contains('too many requests') ||
        text.contains('rate limit');
  }

  static bool _isDuplicateEmailAuthResponse(AuthResponse response) {
    final identities = response.user?.identities;
    return response.user != null && identities != null && identities.isEmpty;
  }

  // Função de Registo (com os metadados do RF01)
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
    required String cpf,
    required String dateOfBirth,
    String? guardianCpf,
  }) async {
    if (await isCpfRegistered(cpf)) {
      throw const DuplicateRegistrationException(
        DuplicateRegistrationField.cpf,
      );
    }

    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'cpf': cpf,
          'date_of_birth': dateOfBirth,
          'guardian_cpf': guardianCpf,
        },
      );

      if (_isDuplicateEmailAuthResponse(response)) {
        throw const DuplicateRegistrationException(
          DuplicateRegistrationField.email,
        );
      }

      return response;
    } on DuplicateRegistrationException {
      rethrow;
    } on AuthException catch (e) {
      if (isRateLimitError(e)) {
        throw const AuthRateLimitException();
      }
      if (parseDuplicateField(e) == DuplicateRegistrationField.email) {
        throw const DuplicateRegistrationException(
          DuplicateRegistrationField.email,
        );
      }
      rethrow;
    } on PostgrestException catch (e) {
      if (parseDuplicateField(e) == DuplicateRegistrationField.cpf) {
        throw const DuplicateRegistrationException(
          DuplicateRegistrationField.cpf,
        );
      }
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    await _supabase.auth.resetPasswordForEmail(
      email.trim().toLowerCase(),
    );
  }

  // Função de Logout
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}