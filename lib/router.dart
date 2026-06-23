import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:inkflow/features/auth/providers/auth_provider.dart';
import 'package:inkflow/features/auth/presentation/splash_screen.dart';
import 'package:inkflow/features/auth/presentation/register_screen.dart';
import 'package:inkflow/features/home/presentation/home_screen.dart';
import 'package:inkflow/features/search/presentation/search_screen.dart';
import 'package:inkflow/features/chat/presentation/chat_screen.dart';
import 'package:inkflow/features/chat/presentation/inbox_screen.dart';
import 'package:inkflow/features/schedule/presentation/schedule_screen.dart';
import 'package:inkflow/features/schedule/presentation/anamnesis_screen.dart';
import 'package:inkflow/features/schedule/presentation/reminders_screen.dart';
import 'package:inkflow/features/dashboard/presentation/dashboard_screen.dart';
import 'package:inkflow/features/profile/presentation/profile_setup_screen.dart';
import 'package:inkflow/features/profile/presentation/profile_screen.dart';
import 'package:inkflow/features/schedule/presentation/care_screen.dart';
import 'package:inkflow/features/schedule/presentation/favorites_screen.dart';
import 'package:inkflow/features/home/presentation/artist_home_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation:
        '/', // <-- CORREÇÃO: O ponto de partida é sempre o Login/Splash
    redirect: (context, state) {
      if (authState.isLoading) return null;

      final isAuthenticated = authState.value?.session != null;
      final isGoingToLogin = state.matchedLocation == '/';
      final isGoingToRegister = state.matchedLocation == '/register';

      // Se NÃO está autenticado e tenta aceder a ecrãs privados, volta ao login
      if (!isAuthenticated && !isGoingToLogin && !isGoingToRegister) {
        return '/';
      }

      // Se ESTÁ autenticado e tenta ir para o login, é empurrado para o Hub (Home)
      if (isAuthenticated && (isGoingToLogin || isGoingToRegister)) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
          path: '/search', builder: (context, state) => const SearchScreen()),
      GoRoute(path: '/inbox', builder: (context, state) => const InboxScreen()),
      GoRoute(
        path: '/chat',
        builder: (context, state) {
          final artistId = state.uri.queryParameters['artistId'] ?? '1';
          return ChatScreen(artistId: artistId);
        },
      ),
      GoRoute(
          path: '/schedule',
          builder: (context, state) => const ScheduleScreen()),
      GoRoute(
          path: '/anamnesis',
          builder: (context, state) => const AnamnesisScreen()),
      GoRoute(
          path: '/reminders',
          builder: (context, state) => const RemindersScreen()),
      GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen()),
      GoRoute(
          path: '/profile', builder: (context, state) => const ProfileScreen()),
      GoRoute(
          path: '/profile-setup',
          builder: (context, state) => const ProfileSetupScreen()),
      GoRoute(
          path: '/artist-home',
          builder: (context, state) => const ArtistHomeScreen()),
      GoRoute(path: '/care', builder: (context, state) => const CareScreen()),
      GoRoute(
          path: '/favorites',
          builder: (context, state) => const FavoritesScreen()),
    ],
  );
});
