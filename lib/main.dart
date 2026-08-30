import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:inkflow/core/theme/app_theme.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Carrega os dados de localizacao usados por `DateFormat(..., 'pt_BR')`.
  // Sem esta chamada qualquer formatacao com locale explicito lanca
  // LocaleDataException em runtime.
  await initializeDateFormatting('pt_BR');

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Erro ao carregar .env: $e');
    runApp(const _StartupErrorApp(
      message:
          'Arquivo .env não encontrado. Copie .env.example para .env e configure SUPABASE_URL e SUPABASE_ANON_KEY.',
    ));
    return;
  }

  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null ||
      supabaseUrl.isEmpty ||
      supabaseAnonKey == null ||
      supabaseAnonKey.isEmpty) {
    runApp(const _StartupErrorApp(
      message:
          'SUPABASE_URL e SUPABASE_ANON_KEY devem estar definidos no arquivo .env.',
    ));
    return;
  }

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      // `anonKey` está depreciado em favor de `publishableKey`; é a mesma chave.
      publishableKey: supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Erro ao inicializar Supabase: $e');
    runApp(const _StartupErrorApp(
      message: 'Falha ao conectar com o Supabase. Verifique as credenciais.',
    ));
    return;
  }

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };

  runApp(
    const ProviderScope(
      child: InkFlowApp(),
    ),
  );
}

class _StartupErrorApp extends StatelessWidget {
  final String message;

  const _StartupErrorApp({required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InkFlow',
      debugShowCheckedModeBanner: false,
      theme: InkFlowTheme.theme,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 64, color: InkFlowColors.error),
                const SizedBox(height: 24),
                const Text(
                  'Erro de configuração',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, color: InkFlowColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class InkFlowApp extends ConsumerWidget {
  const InkFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'InkFlow',
      debugShowCheckedModeBanner: false,
      theme: InkFlowTheme.theme,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // O app e escrito integralmente em pt-BR; declarar en_US sem traducoes
      // fazia o Flutter escolher um locale sem strings correspondentes.
      supportedLocales: const [Locale('pt', 'BR')],
      locale: const Locale('pt', 'BR'),
    );
  }
}
