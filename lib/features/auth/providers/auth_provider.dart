import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inkflow/features/auth/data/auth_repository.dart';

// 1. Fornece a instância do Repositório
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(Supabase.instance.client);
});

// 2. A CORREÇÃO MESTRA: Ouvir diretamente a Stream nativa do Supabase.
// Isso garante 100% que o seu GoRouter vai ser notificado no momento do Login!
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

// 3. Atalho rápido e seguro para o utilizador atual
final currentUserProvider = Provider<User?>((ref) {
  return Supabase.instance.client.auth.currentUser;
});
