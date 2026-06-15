import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _email = 'marcos@inkflow.com';
  String _password = '••••••••';
  bool _isLoading = false;

  void _handleLogin() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() => _isLoading = false);
      context.go('/home');
    }
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Hero
                Column(
                  children: [
                    const SizedBox(height: 60),
                    Image.asset('assets/inkflow_logo.png', height: 80),
                    const SizedBox(height: 8),
                    Text(
                      'A plataforma para tatuadores e clientes',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: InkFlowColors.accent.withOpacity(0.8),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Email
                    _darkLabel('E-mail'),
                    const SizedBox(height: 4),
                    _darkInput(
                      value: _email,
                      onChanged: (v) => setState(() => _email = v),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),

                    // Senha
                    _darkLabel('Senha'),
                    const SizedBox(height: 4),
                    _darkInput(
                      value: _password,
                      onChanged: (v) => setState(() => _password = v),
                      obscure: true,
                    ),
                    const SizedBox(height: 4),

                    // Esqueceu senha
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        child: Text(
                          'Esqueceu a senha?',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
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
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'ou',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    InkButton(
                      label: 'Criar nova conta',
                      onPressed: () => context.go('/register'),
                      isOutlined: true,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Ao continuar, você concorda com os Termos de Uso e Política de Privacidade da InkFlow',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.2),
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
    );
  }

  Widget _darkLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.6),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _darkInput({
    required String value,
    required ValueChanged<String> onChanged,
    TextInputType? keyboardType,
    bool obscure = false,
  }) {
    return TextFormField(
      initialValue: value,
      obscureText: obscure,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: InkFlowColors.accent.withOpacity(0.6), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
