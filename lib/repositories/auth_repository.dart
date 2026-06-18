import 'package:supabase_flutter/supabase_flutter.dart';

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

  // Função de Registo (com os metadados do RF01)
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
    required String cpf,
    required String dateOfBirth,
    String? guardianCpf,
  }) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'name': name,
        'cpf': cpf,
        'date_of_birth': dateOfBirth,
        'guardian_cpf': guardianCpf,
      },
    );
  }

  // Função de Logout
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}