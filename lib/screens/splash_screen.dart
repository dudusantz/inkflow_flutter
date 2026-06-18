import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../providers/auth_provider.dart';

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
    // ==========================================
    // 🚧 MODO BYPASS ATIVADO (PARA TIRAR PRINTS)
    // ==========================================

    // 1. Validação desligada: Assim você não precisa nem digitar e-mail e senha
    // if (!_formKey.currentState!.validate()) return;
    // _formKey.currentState!.save();

    /* 2. CÓDIGO ORIGINAL COMENTADO (Sem Supabase)
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).signIn(_email, _password);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('E-mail ou senha incorretos.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
      setState(() => _isLoading = false);
    }
    */

    // 3. Navegação forçada e direta para o MENU PRINCIPAL
    context.go('/home');
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
                      Image.asset('assets/inkflow_logo.png', height: 80),
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
                          onPressed: () {},
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
