import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:inkflow/core/data/supabase_providers.dart';
import 'package:inkflow/features/auth/data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

/// Stream nativa do Supabase — a fonte de verdade da sessao.
final authStateProvider = authStateChangesProvider;

/// Usuario autenticado atual.
///
/// Depende de [currentUserIdProvider], que observa `onAuthStateChange`. A
/// versao anterior era um `Provider` simples que lia `auth.currentUser` uma
/// unica vez e mantinha o valor em cache para sempre, devolvendo o usuario
/// antigo depois de um logout.
final currentUserProvider = Provider<User?>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(supabaseClientProvider).auth.currentUser;
});

/// `true` quando existe sessao ativa.
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentUserIdProvider) != null;
});
