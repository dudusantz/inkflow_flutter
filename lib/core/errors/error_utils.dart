import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inkflow/core/theme/app_theme.dart';

/// Converte erros técnicos em mensagens amigáveis em português.
String userFriendlyErrorMessage(Object error) {
  if (error is AuthException) {
    final msg = error.message.toLowerCase();
    if (msg.contains('invalid login') || msg.contains('invalid credentials')) {
      return 'E-mail ou senha incorretos.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Confirme seu e-mail antes de entrar.';
    }
    return error.message;
  }

  if (error is PostgrestException) {
    if (error.code == 'PGRST116') return 'Registro não encontrado.';
    return 'Erro ao acessar dados. Tente novamente.';
  }

  if (error is StorageException) {
    return 'Erro ao enviar arquivo. Verifique sua conexão.';
  }

  final msg = error.toString().toLowerCase();
  if (msg.contains('socketexception') ||
      msg.contains('failed host lookup') ||
      msg.contains('network is unreachable')) {
    return 'Sem conexão com a internet. Verifique sua rede.';
  }
  if (msg.contains('timeouterror') || msg.contains('timeout')) {
    return 'A operação demorou demais. Tente novamente.';
  }

  return 'Ocorreu um erro inesperado. Tente novamente.';
}

void showSuccessSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

void showErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Widget reutilizável para estados de erro em providers assíncronos.
class AsyncErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  final String? customMessage;

  const AsyncErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    final message = customMessage ?? userFriendlyErrorMessage(error);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.grey.shade400, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Tentar novamente'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: InkFlowColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
