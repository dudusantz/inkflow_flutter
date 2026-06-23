import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:inkflow/features/home/presentation/artist_home_screen.dart';
import 'package:inkflow/features/home/presentation/client_home_screen.dart';

// Este Provider vai ao Supabase ler o perfil do utilizador logado
final userRoleProvider = FutureProvider<String?>((ref) async {
  try {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return null;

    // Procura na tabela 'profiles' a coluna 'role' deste utilizador
    final response = await supabase
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();

    if (response != null && response['role'] != null) {
      return response['role'] as String;
    }

    // Se o utilizador não tiver uma role definida ainda, assumimos que é Cliente
    return 'CLIENT';
  } catch (e) {
    debugPrint('Erro ao ler a role do utilizador: $e');
    return 'CLIENT'; // Fallback de segurança para mostrar o ecrã de Cliente
  }
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fica à escuta da resposta do Supabase
    final userRoleAsync = ref.watch(userRoleProvider);

    return userRoleAsync.when(
      // Quando os dados chegarem...
      data: (role) {
        // O Hub decide qual ecrã mostrar com base na role real da base de dados!
        if (role == 'ARTIST') {
          return const ArtistHomeScreen(); // Carrega o Dashboard Financeiro
        } else {
          return const ClientHomeScreen(); // Carrega o ecrã com Estúdios e Pesquisa
        }
      },

      // Enquanto a internet pensa, mostra um loading
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF10B981)),
        ),
      ),

      // Se a internet falhar
      error: (error, stack) => const Scaffold(
        body: Center(
          child: Text('Erro ao carregar o seu perfil.'),
        ),
      ),
    );
  }
}
