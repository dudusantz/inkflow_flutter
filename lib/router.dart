import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:inkflow/core/data/supabase_providers.dart';
import 'package:inkflow/features/auth/presentation/auth_callback_screen.dart';
import 'package:inkflow/features/auth/presentation/register_screen.dart';
import 'package:inkflow/features/auth/presentation/splash_screen.dart';
import 'package:inkflow/features/chat/presentation/chat_screen.dart';
import 'package:inkflow/features/chat/presentation/inbox_screen.dart';
import 'package:inkflow/features/dashboard/presentation/dashboard_screen.dart';
import 'package:inkflow/features/home/presentation/artist_home_screen.dart';
import 'package:inkflow/features/home/presentation/home_screen.dart';
import 'package:inkflow/features/profile/presentation/change_password_screen.dart';
import 'package:inkflow/features/profile/presentation/edit_profile_screen.dart';
import 'package:inkflow/features/profile/presentation/notifications_screen.dart';
import 'package:inkflow/features/profile/presentation/privacy_screen.dart';
import 'package:inkflow/features/profile/presentation/profile_screen.dart';
import 'package:inkflow/features/profile/presentation/profile_setup_screen.dart';
import 'package:inkflow/features/schedule/presentation/anamnesis_screen.dart';
import 'package:inkflow/features/schedule/presentation/care_screen.dart';
import 'package:inkflow/features/schedule/presentation/favorites_screen.dart';
import 'package:inkflow/features/schedule/presentation/reminders_screen.dart';
import 'package:inkflow/features/schedule/presentation/schedule_screen.dart';
import 'package:inkflow/features/search/presentation/search_screen.dart';

/// Rotas acessiveis sem sessao ativa.
const _publicRoutes = {'/', '/register', '/callback'};

/// Destino do guard de autenticacao, ou `null` para seguir na rota pedida.
///
/// Extraido do `redirect` para poder ser testado sem subir um GoRouter nem uma
/// sessao real do Supabase.
String? authRedirect({
  required bool isAuthenticated,
  required String location,
}) {
  final isPublic = _publicRoutes.contains(location);
  if (!isAuthenticated && !isPublic) return '/';
  if (isAuthenticated && isPublic && location != '/callback') return '/home';
  return null;
}

/// Id do interlocutor do chat, ou `null` quando o link nao traz um.
///
/// Aceita `artistId` como alias legado dos links gerados pela busca.
String? chatContactIdOf(Uri uri) {
  final id = uri.queryParameters['contactId'] ?? uri.queryParameters['artistId'];
  return (id == null || id.trim().isEmpty) ? null : id.trim();
}

/// Adapta uma `Stream` ao `Listenable` esperado pelo GoRouter.
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final supabase = ref.watch(supabaseClientProvider);

  // O router e construido uma unica vez e apenas reavalia o redirect quando a
  // sessao muda. Antes ele fazia `ref.watch(authStateProvider)`, o que recriava
  // o GoRouter inteiro — e zerava a pilha de navegacao — a cada evento de auth,
  // inclusive no `tokenRefreshed` que ocorre a cada hora.
  final refresh = GoRouterRefreshStream(supabase.auth.onAuthStateChange);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) => authRedirect(
      isAuthenticated: supabase.auth.currentSession != null,
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen()),
      GoRoute(
        path: '/callback',
        builder: (context, state) => const AuthCallbackScreen(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
          path: '/search', builder: (context, state) => const SearchScreen()),
      GoRoute(path: '/inbox', builder: (context, state) => const InboxScreen()),
      GoRoute(
        path: '/chat',
        // Sem um interlocutor valido nao ha conversa. O fallback anterior era
        // `?? '1'`, que nao e um UUID e fazia o insert da mensagem falhar no
        // banco com um erro incompreensivel para o usuario.
        redirect: (context, state) =>
            chatContactIdOf(state.uri) == null ? '/inbox' : null,
        builder: (context, state) => ChatScreen(
          contactId: chatContactIdOf(state.uri)!,
        ),
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
      GoRoute(
          path: '/edit-profile',
          builder: (context, state) => const EditProfileScreen()),
      GoRoute(
          path: '/change-password',
          builder: (context, state) => const ChangePasswordScreen()),
      GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationsScreen()),
      GoRoute(
          path: '/privacy', builder: (context, state) => const PrivacyScreen()),
    ],
  );
});
