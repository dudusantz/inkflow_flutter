import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Ponto unico de acesso ao cliente Supabase.
///
/// Os repositorios dependem deste provider em vez de chamarem
/// `Supabase.instance.client` diretamente, o que permite sobrescrever o cliente
/// por um fake nos testes.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Id do usuario autenticado, ou `null` quando nao ha sessao.
///
/// Diferente de um `Provider` que le `currentUser` uma unica vez, este observa
/// `onAuthStateChange` e por isso nunca devolve um usuario obsoleto apos
/// login/logout.
final currentUserIdProvider = Provider<String?>((ref) {
  final auth = ref.watch(authStateChangesProvider);
  return auth.value?.session?.user.id ??
      ref.watch(supabaseClientProvider).auth.currentUser?.id;
});

final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});
