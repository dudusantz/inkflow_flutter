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

  void _handleLogin() async {
    // 1. Validação de formulário ativa
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    try {
      // 2. Chamada real para a API do Supabase
      await ref.read(authRepositoryProvider).signIn(_email, _password);

      // 3. Sucesso: Para o loading e vai para a Home
      if (mounted) {
        setState(() => _isLoading = false);
        context.go('/home');
      }
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
    emailController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InkFlowColors.primary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Hero
                  Column(
                    children: [
                      const SizedBox(height: 60),
                      const InkFlowLogo(height: 80),
                      const SizedBox(height: 8),
                      const Text(
                        'A plataforma para tatuadores e clientes',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xCCFFFFFF),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 48),

                      // Email
                      _darkLabel('E-mail'),
                      const SizedBox(height: 4),
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
                      const SizedBox(height: 12),

                      // Senha
                      _darkLabel('Senha'),
                      const SizedBox(height: 4),
                      _darkInput(
                        hint: '••••••••',
                        obscure: true,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Informe sua senha' : null,
                        onSaved: (v) => _password = v!,
                      ),
                      const SizedBox(height: 4),

                      // Esqueceu senha
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _showForgotPassword,
                          child: const Text(
                            'Esqueceu a senha?',
                            style: TextStyle(
                              color: Color(0x66FFFFFF),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Entrar
                      InkButton(
                        label: 'Entrar',
                        isLoading: _isLoading,
                        onPressed: _handleLogin,
                      ),
                    ],
                  ),

                  // Footer
                  Column(
                    children: [
                      const SizedBox(height: 32),
                      const Row(
                        children: [
                          Expanded(child: Divider(color: Color(0x1AFFFFFF))),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'ou',
                              style: TextStyle(
                                color: Color(0x4DFFFFFF),
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: Color(0x1AFFFFFF))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      InkButton(
                        label: 'Criar nova conta',
                        onPressed: () => context.go('/register'),
                        isOutlined: true,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Ao continuar, você concorda com os Termos de Uso e Política de Privacidade da InkFlow',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0x33FFFFFF),
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ],
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
              color: InkFlowColors.accent.withOpacity(0.6), width: 1.5),
        ),
        errorStyle: const TextStyle(color: Color(0xFFEF4444)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
