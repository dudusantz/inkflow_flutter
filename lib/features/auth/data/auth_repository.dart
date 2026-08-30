import 'package:supabase_flutter/supabase_flutter.dart';

/// Deep link registrado no Android, iOS e na lista de URLs permitidas do
/// Supabase. Centralizá-lo evita divergências entre cadastro e recuperação.
const authCallbackUrl = 'inkflow://auth/callback';

enum DuplicateRegistrationField { email, cpf }

class DuplicateRegistrationException implements Exception {
  final DuplicateRegistrationField field;

  const DuplicateRegistrationException(this.field);
}

class AuthRateLimitException implements Exception {
  const AuthRateLimitException();
}

/// A senha atual informada na troca de senha nao confere.
class InvalidCurrentPasswordException implements Exception {
  const InvalidCurrentPasswordException();
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

  static DuplicateRegistrationField? parseDuplicateField(Object error) {
    final message = error.toString().toLowerCase();

    // Erro levantado pelo trigger `handle_new_user` (migration 002) quando o
    // indice unico `profiles_cpf_key` e violado.
    if (message.contains('cpf_already_registered')) {
      return DuplicateRegistrationField.cpf;
    }

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

    // O GoTrue mascara excecoes do trigger como "Database error saving new
    // user". No cadastro, a unica restricao que o trigger pode violar e o
    // indice unico de CPF.
    if (message.contains('database error saving new user')) {
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

  /// Cadastro do RF01.
  ///
  /// `cpf`, `dateOfBirth` e `guardianCpf` viajam no metadata apenas ate o
  /// trigger `handle_new_user` copia-los para `profiles` e apaga-los de la — o
  /// metadata do Supabase e editavel pelo proprio usuario e nao serve para
  /// guardar identidade.
  ///
  /// A duplicidade de CPF e detectada pelo indice unico no banco. A versao
  /// anterior consultava `profiles` antes do login, o que permitia a qualquer
  /// pessoa com a anon key testar se um CPF estava cadastrado.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
    required String cpf,
    required String dateOfBirth,
    String? guardianCpf,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: authCallbackUrl,
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
      final field = parseDuplicateField(e);
      if (field != null) throw DuplicateRegistrationException(field);
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

  /// Troca a senha exigindo a senha atual.
  ///
  /// A versao anterior chamava `updateUser(password:)` direto: qualquer pessoa
  /// com o aparelho desbloqueado — ou com uma sessao sequestrada — trocava a
  /// senha e assumia a conta. A reautenticacao fecha essa porta.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final email = currentUser?.email;
    if (email == null) {
      throw const AuthException('Sessão expirada. Entre novamente.');
    }

    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
    } on AuthException catch (e) {
      if (isRateLimitError(e)) throw const AuthRateLimitException();
      throw const InvalidCurrentPasswordException();
    }

    await _supabase.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> resetPassword(String email) async {
    await _supabase.auth.resetPasswordForEmail(
      email.trim().toLowerCase(),
      redirectTo: authCallbackUrl,
    );
  }

  // Função de Logout
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
