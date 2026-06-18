import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; 

import 'theme/app_theme.dart';
import 'router.dart'; // Onde está o nosso novo routerProvider

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Carrega as variáveis de ambiente (.env)
  await dotenv.load(fileName: ".env");

  // 2. Inicializa o Supabase lendo do .env
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(
    // O ProviderScope é obrigatório para o Riverpod funcionar no app todo
    const ProviderScope(
      child: InkFlowApp(),
    ),
  );
}

// Transformado de StatelessWidget para ConsumerWidget
class InkFlowApp extends ConsumerWidget {
  const InkFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // AQUI ESTÁ A CORREÇÃO:
    // Nós consumimos o routerProvider do Riverpod e guardamos na variável local "router"
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'InkFlow',
      debugShowCheckedModeBanner: false,
      theme: InkFlowTheme.theme,
      routerConfig: router, // Passamos a variável reativa "router" (e não mais o appRouter fixo)
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
        Locale('en', 'US'),
      ],
    );
  }
}