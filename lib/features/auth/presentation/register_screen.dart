import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:inkflow/core/theme/app_theme.dart';
import 'package:inkflow/core/widgets/shared_widgets.dart';
import 'package:inkflow/features/auth/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inkflow/features/auth/data/auth_repository.dart';

extension AgeCalculator on DateTime {
  int get age {
    final today = DateTime.now();
    int age = today.year - year;
    if (today.month < month || (today.month == month && today.day < day)) {
      age--;
    }
    return age;
  }
}

class CpfValidator {
  static bool isValid(String cpf) {
    cpf = cpf.replaceAll(RegExp(r'[^0-9]'), '');
    if (cpf.length != 11) return false;
    if (RegExp(r'^(\d)\1*$').hasMatch(cpf)) return false;

    List<int> numbers = cpf.split('').map(int.parse).toList();

    int sum = 0;
    for (int i = 0; i < 9; i++) {
      sum += numbers[i] * (10 - i);
    }
    int check1 = 11 - (sum % 11);
    if (check1 >= 10) check1 = 0;
    if (check1 != numbers[9]) return false;

    sum = 0;
    for (int i = 0; i < 10; i++) {
      sum += numbers[i] * (11 - i);
    }
    int check2 = 11 - (sum % 11);
    if (check2 >= 10) check2 = 0;
    if (check2 != numbers[10]) return false;

    return true;
  }
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controller para monitorar a senha principal em tempo real
  final _passwordController = TextEditingController();

  final _cpfMaskFormatter = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  bool _isLoading = false;
  bool _terms = false;
  String? _errorMessage;
  DuplicateRegistrationField? _duplicateField;
  DateTime? _rateLimitUntil;

  String _name = '';
  String _email = '';
  String _cpf = '';
  String _password = '';
  String _guardianCpf = '';

  DateTime? _selectedDob;

  bool get _isUnderage => _selectedDob != null && _selectedDob!.age < 18;

  bool get _guardianValid =>
      !_isUnderage || CpfValidator.isValid(_guardianCpf);

  @override
  void dispose() {
    // É obrigatório descartar controllers em State para evitar memory leaks
    _passwordController.dispose();
    super.dispose();
  }

  bool get _canSubmit => _guardianValid && !_isRateLimited;

  bool get _isRateLimited =>
      _rateLimitUntil != null && DateTime.now().isBefore(_rateLimitUntil!);

  void _applyRateLimitCooldown() {
    setState(() {
      _rateLimitUntil = DateTime.now().add(const Duration(minutes: 2));
      _isLoading = false;
      _errorMessage =
          'Limite de tentativas atingido no Supabase. Aguarde cerca de 2 minutos '
          'e tente novamente — ou faça login se a conta já foi criada.';
    });
  }

  void _handleSubmit() async {
    if (_isLoading || _isRateLimited) return;

    setState(() {
      _errorMessage = null;
      _duplicateField = null;
    });

    if (!_terms) {
      setState(() => _errorMessage = 'Você precisa aceitar os Termos de Uso.');
      return;
    }

    if (_formKey.currentState!.validate()) {
      if (_selectedDob == null) {
        setState(() => _errorMessage = 'Selecione sua data de nascimento.');
        return;
      }

      _formKey.currentState!.save();
      setState(() => _isLoading = true); // Inicia o loading

      try {
        final String cleanDate =
            '${_selectedDob!.year}-${_selectedDob!.month.toString().padLeft(2, '0')}-${_selectedDob!.day.toString().padLeft(2, '0')}';
        final String cleanCpf = _cpf.replaceAll(RegExp(r'[^0-9]'), '');
        final String cleanGuardianCpf =
            _guardianCpf.replaceAll(RegExp(r'[^0-9]'), '');
        final String cleanEmail =
            _email.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');

        // Dispara a requisição para o banco
        await ref.read(authRepositoryProvider).signUp(
              email: cleanEmail,
              password: _password,
              name: _name,
              cpf: cleanCpf,
              dateOfBirth: cleanDate,
              guardianCpf: _isUnderage ? cleanGuardianCpf : null,
            );

        // 👇 CORREÇÃO: O que fazer quando dá certo
        if (mounted) {
          setState(() => _isLoading = false); // Para o loading imediatamente

          // O Supabase tem sessão ativa? (Ou seja, login automático ocorreu?)
          final session = Supabase.instance.client.auth.currentSession;

          if (session == null) {
            // Cenário 1: Conta criada, mas exige confirmação de e-mail
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('Conta criada! Verifique seu e-mail ou faça o login.'),
                backgroundColor: Color(0xFF10B981), // Verde
              ),
            );
            context.go('/'); // Manda o usuário para a tela de login inicial
          } else {
            // Cenário 2: Login automático ocorreu com sucesso
            context.go('/home');
          }
        }
      } on DuplicateRegistrationException catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _duplicateField = e.field;
            _errorMessage = 'Usuário já cadastrado.';
          });
        }
      } on AuthRateLimitException catch (_) {
        if (mounted) _applyRateLimitCooldown();
      } on AuthException catch (e) {
        if (mounted) {
          if (AuthRepository.isRateLimitError(e)) {
            _applyRateLimitCooldown();
          } else {
            setState(() {
              _isLoading = false;
              _errorMessage =
                  'Erro ao criar conta. Verifique os dados e tente novamente.';
            });
          }
        }
      } catch (e) {
        if (mounted) {
          if (AuthRepository.isRateLimitError(e)) {
            _applyRateLimitCooldown();
            return;
          }
          setState(() {
            _isLoading = false;
            final duplicateField = AuthRepository.parseDuplicateField(e);
            if (duplicateField != null) {
              _duplicateField = duplicateField;
              _errorMessage = 'Usuário já cadastrado.';
            } else {
              _errorMessage =
                  'Erro ao criar conta. Verifique os dados e tente novamente.';
            }
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InkFlowColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(
                title: 'Criar Conta', showBack: true, backTo: '/', dark: true),
            Expanded(child: _buildForm()),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: InkFlowColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: InkFlowColors.error.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Color(0xFFEF4444), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_errorMessage!,
                              style: const TextStyle(
                                  color: Color(0xFFEF4444), fontSize: 12)),
                        ),
                      ],
                    ),
                    if (_duplicateField != null) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _goToPasswordRecovery,
                        child: const Text(
                          'Ir para Recuperação de Senha →',
                          style: TextStyle(
                            color: InkFlowColors.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            _buildValidatedField(
              label: 'Nome completo *',
              validator: (v) =>
                  v == null || v.isEmpty ? 'Campo obrigatório' : null,
              onSaved: (v) => _name = v!,
            ),
            const SizedBox(height: 16),
            _buildValidatedField(
              label: 'E-mail *',
              keyboardType: TextInputType.emailAddress,
              hasError: _duplicateField == DuplicateRegistrationField.email,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Campo obrigatório';
                if (!v.contains('@')) return 'E-mail inválido';
                return null;
              },
              onSaved: (v) => _email = v!,
            ),
            const SizedBox(height: 16),
            _buildValidatedField(
              label: 'CPF *',
              keyboardType: TextInputType.number,
              inputFormatters: [_cpfMaskFormatter],
              hasError: _duplicateField == DuplicateRegistrationField.cpf,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Campo obrigatório';
                if (!CpfValidator.isValid(v)) return 'CPF inválido';
                return null;
              },
              onSaved: (v) => _cpf = v!,
            ),
            const SizedBox(height: 16),
            _dobField(),
            const SizedBox(height: 16),
            if (_isUnderage) _guardianField(),
            _buildValidatedField(
              label: 'Senha *',
              controller: _passwordController,
              obscureText: true,
              validator: (v) => v == null || v.length < 6
                  ? 'A senha deve ter no mínimo 6 caracteres'
                  : null,
              onSaved: (v) => _password = v!,
            ),
            const SizedBox(height: 16),
            _buildValidatedField(
              label: 'Confirmar Senha *',
              obscureText: true,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Confirme sua senha';
                if (v != _passwordController.text) {
                  return 'As senhas não coincidem';
                }
                return null;
              },
              onSaved: (v) {},
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => setState(() => _terms = !_terms),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: _terms ? InkFlowColors.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _terms
                            ? InkFlowColors.accent
                            : Colors.white.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: _terms
                        ? const Icon(Icons.check,
                            color: InkFlowColors.primary, size: 12)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(
                            color: Color(0x80FFFFFF),
                            fontSize: 12,
                            height: 1.5),
                        children: [
                          TextSpan(text: 'Aceito os '),
                          TextSpan(
                              text: 'Termos de Uso',
                              style: TextStyle(
                                  color: InkFlowColors.accent,
                                  decoration: TextDecoration.underline)),
                          TextSpan(text: ' e a '),
                          TextSpan(
                              text: 'Política de Privacidade',
                              style: TextStyle(
                                  color: InkFlowColors.accent,
                                  decoration: TextDecoration.underline)),
                          TextSpan(text: ' da InkFlow'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            InkButton(
              label: 'Criar Conta',
              onPressed: (_isLoading || !_canSubmit) ? null : _handleSubmit,
              isLoading: _isLoading,
            ),
            const SizedBox(height: 20),
            Center(
              child: Text.rich(
                TextSpan(
                  style:
                      const TextStyle(color: Color(0x66FFFFFF), fontSize: 12),
                  children: [
                    const TextSpan(text: 'Já tem conta? '),
                    WidgetSpan(
                      child: GestureDetector(
                        onTap: () => context.go('/'),
                        child: const Text('Entrar',
                            style: TextStyle(
                                color: InkFlowColors.accent, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _goToPasswordRecovery() {
    context.go('/');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Use "Esqueceu a senha?" na tela de login para recuperar o acesso.'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  Widget _buildValidatedField({
    required String label,
    required FormFieldValidator<String> validator,
    required FormFieldSetter<String> onSaved,
    bool obscureText = false,
    bool hasError = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextEditingController? controller,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Color(0x99FFFFFF),
                fontSize: 12,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0x1AFFFFFF),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: hasError
                        ? const Color(0xFFEF4444)
                        : const Color(0x1AFFFFFF))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: hasError
                        ? const Color(0xFFEF4444)
                        : const Color(0x1AFFFFFF))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: hasError
                        ? const Color(0xFFEF4444)
                        : InkFlowColors.accent.withValues(alpha: 0.6),
                    width: 1.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            errorStyle: const TextStyle(color: Color(0xFFEF4444)),
          ),
          validator: validator,
          onSaved: onSaved,
        ),
      ],
    );
  }

  Widget _dobField() {
    final dateStr = _selectedDob != null
        ? '${_selectedDob!.day.toString().padLeft(2, '0')}/${_selectedDob!.month.toString().padLeft(2, '0')}/${_selectedDob!.year}'
        : 'Selecionar data';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Data de nascimento *',
            style: TextStyle(
                color: Color(0x99FFFFFF),
                fontSize: 12,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
                color: const Color(0x1AFFFFFF),
                borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Text(dateStr,
                    style: TextStyle(
                        color: _selectedDob == null
                            ? const Color(0x4DFFFFFF)
                            : Colors.white,
                        fontSize: 14)),
                const Spacer(),
                const Icon(Icons.calendar_today,
                    color: Color(0x66FFFFFF), size: 16),
              ],
            ),
          ),
        ),
        if (_isUnderage) ...[
          const SizedBox(height: 8),
          Text(
            'Você possui ${_selectedDob!.age} anos. Menores de 18 anos precisam incluir o CPF de um responsável legal.',
            style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11),
          ),
        ],
      ],
    );
  }

  Widget _guardianField() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: InkFlowColors.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: InkFlowColors.error.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CPF do Responsável Legal *',
            style: TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextFormField(
            keyboardType: TextInputType.number,
            inputFormatters: [_cpfMaskFormatter],
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: '000.000.000-00',
              hintStyle: const TextStyle(color: Color(0x4DFFFFFF)),
              filled: true,
              fillColor: const Color(0x1AFFFFFF),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              errorStyle: const TextStyle(color: Color(0xFFEF4444)),
            ),
            validator: (v) {
              if (_isUnderage && (v == null || v.isEmpty)) {
                return 'Obrigatório para menores';
              }
              if (_isUnderage && !CpfValidator.isValid(v!)) {
                return 'CPF do responsável inválido';
              }
              return null;
            },
            onSaved: (v) => _guardianCpf = v ?? '',
            onChanged: (v) => setState(() => _guardianCpf = v),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
              primary: InkFlowColors.accent, onPrimary: InkFlowColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDob = picked);
    }
  }
}
