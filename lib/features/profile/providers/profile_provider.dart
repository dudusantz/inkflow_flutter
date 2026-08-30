import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:inkflow/core/data/supabase_providers.dart';
import 'package:inkflow/features/profile/data/profile_repository.dart';
import 'package:inkflow/features/profile/domain/user_profile.dart';

/// Perfil do usuario logado.
///
/// Esta e a unica leitura de `profiles` para o proprio usuario. Antes havia
/// quatro providers concorrentes (`userRoleProvider`, `clientProfileProvider`,
/// `userProfileProvider` e uma consulta embutida na agenda) buscando a mesma
/// linha com regras de fallback diferentes.
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  // Observar o id faz o perfil ser refeito em login/logout.
  ref.watch(currentUserIdProvider);
  return ref.watch(profileRepositoryProvider).fetchMyProfile();
});

/// Papel do usuario (`ARTIST` ou `CLIENT`), derivado do perfil.
final userRoleProvider = FutureProvider<String>((ref) async {
  final profile = await ref.watch(userProfileProvider.future);
  return profile?.role ?? 'CLIENT';
});

/// Versao sincrona do papel, para telas que precisam decidir layout durante o
/// carregamento. Assume `CLIENT` enquanto o perfil nao chegou.
final isArtistProvider = Provider<bool>((ref) {
  return ref.watch(userRoleProvider).value == 'ARTIST';
});
