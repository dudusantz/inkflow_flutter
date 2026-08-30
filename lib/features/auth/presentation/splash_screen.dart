import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inkflow/core/theme/app_theme.dart';
import 'package:inkflow/core/widgets/shared_widgets.dart';
import 'package:inkflow/features/auth/providers/auth_provider.dart';
import 'package:inkflow/features/auth/data/auth_repository.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  final _formKey = GlobalKey<FormState>();

  String _email = '';
  String _password = '';
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    try {
      await ref.read(authRepositoryProvider).signIn(_email, _password);

      // A navegação fica por conta do `redirect` do router, que reage ao
      // `onAuthStateChange`. Um `context.go('/home')` aqui competia com ele e
      // gerava navegação dupla.
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      // 4. Tratamento de Erro Sênior
      if (mounted) {
        setState(() => _isLoading = false);

        String errorMessage = 'E-mail ou senha incorretos.';

        if (AuthRepository.isRateLimitError(e)) {
          errorMessage =
              'Muitas tentativas. Aguarde alguns minutos e tente novamente.';
        } else if (e.toString().toLowerCase().contains('email not confirmed')) {
          errorMessage =
              'E-mail não confirmado. Verifique o painel do Supabase.';
        } else if (e.toString().contains('Invalid login credentials')) {
          errorMessage = 'E-mail ou senha incorretos.';
        } else {
          errorMessage = 'Erro ao tentar entrar. Tente novamente.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showForgotPassword() async {
    final emailController = TextEditingController(text: _email);
    try {
      await _askForRecoveryEmail(emailController);
    } finally {
      // O `dispose` ficava depois de vários `return` antecipados (cancelar,
      // e-mail inválido, falha no envio) e vazava o controller nesses caminhos.
      emailController.dispose();
    }
  }

  Future<void> _askForRecoveryEmail(
      TextEditingController emailController) async {
    final sent = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recuperar senha'),
        content: TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'E-mail cadastrado',
            hintText: 'exemplo@email.com',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enviar link'),
          ),
        ],
      ),
    );

    if (sent != true || !mounted) return;

    final email = emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe um e-mail válido.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    try {
      await ref.read(authRepositoryProvider).resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link de recuperação enviado para o seu e-mail.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível enviar o link. Tente novamente.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InkFlowColors.primary,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(minHeight: constraints.maxHeight - 56),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const InkFlowLogo(height: 116),
                        const SizedBox(height: 6),
                        const Text(
                          'Arte, conexão e cuidado em um só lugar.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xBFFFFFFF),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 36),
                        _darkLabel('E-mail'),
                        const SizedBox(height: 7),
                        _darkInput(
                          hint: 'exemplo@email.com',
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.isEmpty)
                              return 'Informe seu e-mail';
                            if (!v.contains('@')) return 'E-mail inválido';
                            return null;
                          },
                          onSaved: (v) => _email = v!.trim(),
                        ),
                        const SizedBox(height: 18),
                        _darkLabel('Senha'),
                        const SizedBox(height: 7),
                        _darkInput(
                          hint: '••••••••',
                          obscure: true,
                          validator: (v) => v == null || v.isEmpty
                              ? 'Informe sua senha'
                              : null,
                          onSaved: (v) => _password = v!,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _showForgotPassword,
                            child: const Text(
                              'Esqueceu a senha?',
                              style: TextStyle(
                                color: Color(0xB3FFFFFF),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkButton(
                          label: 'Entrar',
                          isLoading: _isLoading,
                          onDark: true,
                          onPressed: _handleLogin,
                        ),
                        const SizedBox(height: 28),
                        const Row(
                          children: [
                            Expanded(child: Divider(color: Color(0x26FFFFFF))),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 14),
                              child: Text('ou',
                                  style: TextStyle(
                                      color: Color(0x80FFFFFF), fontSize: 12)),
                            ),
                            Expanded(child: Divider(color: Color(0x26FFFFFF))),
                          ],
                        ),
                        const SizedBox(height: 20),
                        InkButton(
                          label: 'Criar nova conta',
                          onPressed: () => context.go('/register'),
                          isOutlined: true,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Ao continuar, você concorda com os Termos de Uso e a Política de Privacidade da InkFlow.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0x66FFFFFF),
                            fontSize: 10,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _darkLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0x99FFFFFF),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _darkInput({
    required String hint,
    required FormFieldSetter<String> onSaved,
    FormFieldValidator<String>? validator,
    TextInputType? keyboardType,
    bool obscure = false,
  }) {
    return TextFormField(
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      onSaved: onSaved,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0x33FFFFFF)),
        filled: true,
        fillColor: const Color(0x1AFFFFFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: InkFlowColors.accent.withValues(alpha: 0.6), width: 1.5),
        ),
        errorStyle: const TextStyle(color: Color(0xFFEF4444)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
