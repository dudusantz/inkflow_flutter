import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:inkflow/core/errors/error_utils.dart';
import 'package:inkflow/core/theme/app_theme.dart';
import 'package:inkflow/features/home/presentation/artist_home_screen.dart';
import 'package:inkflow/features/home/presentation/client_home_screen.dart';
import 'package:inkflow/features/profile/providers/profile_provider.dart';

/// Hub que escolhe a home conforme o papel do usuario.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleAsync = ref.watch(userRoleProvider);

    return roleAsync.when(
      data: (role) => role == 'ARTIST'
          ? const ArtistHomeScreen()
          : const ClientHomeScreen(),
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: InkFlowColors.accent),
        ),
      ),
      error: (error, stack) => Scaffold(
        body: AsyncErrorView(
          error: error,
          customMessage: 'Erro ao carregar o seu perfil.',
          onRetry: () => ref.invalidate(userProfileProvider),
        ),
      ),
    );
  }
}
