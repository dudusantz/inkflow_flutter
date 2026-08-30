import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:inkflow/core/data/supabase_providers.dart';
import 'package:inkflow/core/theme/app_theme.dart';

class AuthCallbackScreen extends ConsumerStatefulWidget {
  const AuthCallbackScreen({super.key});

  @override
  ConsumerState<AuthCallbackScreen> createState() =>
      _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends ConsumerState<AuthCallbackScreen> {
  StreamSubscription<AuthState>? _subscription;
  bool _timedOut = false;
  Timer? _timeout;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(supabaseClientProvider).auth;
    _subscription = auth.onAuthStateChange.listen((state) {
      if (state.session != null && mounted) setState(() {});
    });
    _timeout = Timer(const Duration(seconds: 12), () {
      if (mounted && auth.currentSession == null) {
        setState(() => _timedOut = true);
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _timeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final confirmed =
        ref.read(supabaseClientProvider).auth.currentSession != null;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/inkflow_logo.png', height: 92),
                  const SizedBox(height: 32),
                  Icon(
                    confirmed
                        ? Icons.check_circle_outline
                        : _timedOut
                            ? Icons.error_outline
                            : Icons.mark_email_read_outlined,
                    size: 64,
                    color: confirmed
                        ? InkFlowColors.primary
                        : _timedOut
                            ? InkFlowColors.error
                            : InkFlowColors.textMuted,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    confirmed
                        ? 'E-mail confirmado!'
                        : _timedOut
                            ? 'Não foi possível confirmar'
                            : 'Confirmando seu e-mail…',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    confirmed
                        ? 'Sua conta InkFlow está pronta para ser usada.'
                        : _timedOut
                            ? 'O link pode ter expirado ou já ter sido usado. Tente entrar novamente.'
                            : 'Só um instante enquanto validamos seu cadastro.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: InkFlowColors.textMuted),
                  ),
                  const SizedBox(height: 28),
                  if (!confirmed && !_timedOut)
                    const CircularProgressIndicator()
                  else
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => context.go(confirmed ? '/home' : '/'),
                        child: Text(confirmadoLabel(confirmed)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String confirmadoLabel(bool confirmed) =>
    confirmed ? 'Continuar para o InkFlow' : 'Voltar para entrar';
