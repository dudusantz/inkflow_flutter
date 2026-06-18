import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/auth_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/anamnesis_screen.dart';
import 'screens/reminders_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/profile_setup_screen.dart';

// O Router agora é um Provider reativo.
// Sempre que o estado de Autenticação mudar, ele reavalia as rotas automaticamente.
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',

    // O guarda de rotas (Auth Guard) intercepta todas as mudanças de tela
    redirect: (context, state) {
      // 1. Enquanto o Supabase verifica o token no arranque, aguardamos
      if (authState.isLoading) return null;

      // 2. Verificamos se existe uma sessão ativa válida
      final isAuthenticated = authState.value?.session != null;

      final isGoingToLogin = state.matchedLocation == '/';
      final isGoingToRegister = state.matchedLocation == '/register';

      // 3. Se NÃO está logado e tenta acessar rotas internas -> Manda de volta para o Login
      if (!isAuthenticated && !isGoingToLogin && !isGoingToRegister) {
        return '/';
      }

      // 4. Se ESTÁ logado e tenta acessar Login ou Registro -> Manda direto para a Home
      if (isAuthenticated && (isGoingToLogin || isGoingToRegister)) {
        return '/home';
      }

      return null;
    },

    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) {
          final artistId = state.uri.queryParameters['artistId'] ?? '1';
          return ChatScreen(artistId: artistId);
        },
      ),
      GoRoute(
        path: '/schedule',
        builder: (context, state) => const ScheduleScreen(),
      ),
      GoRoute(
        path: '/anamnesis',
        builder: (context, state) => const AnamnesisScreen(),
      ),
      GoRoute(
        path: '/reminders',
        builder: (context, state) => const RemindersScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
    ],
  );
});
