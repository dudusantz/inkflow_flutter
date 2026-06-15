import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
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
