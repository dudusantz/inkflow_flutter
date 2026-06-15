import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

// Extensão isolada para cálculo de idade - Regra de negócio separada da UI
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

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  
  bool _submitted = false;
  bool _isLoading = false;
  bool _terms = false;
  bool _isDuplicateError = false; // Controle de erro vindo do backend

  String _name = '';
  String _email = '';
  String _cpf = '';
  String _password = '';
  String _guardianCpf = '';
  
  DateTime? _selectedDob;

  bool get _isUnderage => _selectedDob != null && _selectedDob!.age < 18;

  void _handleSubmit() async {
    if (!_terms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você precisa aceitar os Termos de Uso.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      if (_selectedDob == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecione sua data de nascimento.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
        return;
      }

      _formKey.currentState!.save();
      setState(() {
        _isLoading = true;
        _isDuplicateError = false;
      });

      try {
        // TODO: Substituir por chamada real ao backend (Supabase/Firebase)
        // await authService.signUp(...)
        await Future.delayed(const Duration(milliseconds: 1500)); // Simula rede

        if (mounted) {
          setState(() {
            _isLoading = false;
            _submitted = true;
          });
          await Future.delayed(const Duration(milliseconds: 1500));
          if (mounted) context.go('/home');
        }
      } catch (e) {
        // Exemplo de como tratar o RNF de duplicidade vindo do banco
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isDuplicateError = true;
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
            AppHeader(title: 'Criar Conta', showBack: true, backTo: '/', dark: true),
            if (_submitted)
              Expanded(child: _buildSuccess())
            else
              Expanded(child: _buildForm()),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: InkFlowColors.accent.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: InkFlowColors.accent, size: 40),
          ),
          const SizedBox(height: 16),
          const Text('Conta criada!',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            'Redirecionando para a tela inicial...',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
          ),
        ],
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
            if (_isDuplicateError)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '⚠ E-mail ou CPF já cadastrado',
                      style: TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Este e-mail já está em uso. Acesse a tela de Recuperação de Senha.',
                      style: TextStyle(
                          color: const Color(0xFFF59E0B).withOpacity(0.7),
                          fontSize: 12),
                    ),
                  ],
                ),
              ),

            _buildValidatedField(
              label: 'Nome completo *',
              validator: (v) => v == null || v.isEmpty ? 'Campo obrigatório' : null,
              onSaved: (v) => _name = v!,
            ),
            const SizedBox(height: 16),

            _buildValidatedField(
              label: 'E-mail *',
              keyboardType: TextInputType.emailAddress,
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
              validator: (v) => v == null || v.length < 11 ? 'CPF inválido' : null,
              onSaved: (v) => _cpf = v!,
            ),
            const SizedBox(height: 16),

            _dobField(),
            const SizedBox(height: 16),

            if (_isUnderage) _guardianField(),

            _buildValidatedField(
              label: 'Senha *',
              obscureText: true,
              validator: (v) => v == null || v.length < 6 ? 'A senha deve ter no mínimo 6 caracteres' : null,
              onSaved: (v) => _password = v!,
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
                            : Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: _terms
                        ? const Icon(Icons.check, color: InkFlowColors.primary, size: 12)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                            height: 1.5),
                        children: [
                          const TextSpan(text: 'Aceito os '),
                          TextSpan(
                            text: 'Termos de Uso',
                            style: const TextStyle(
                                color: InkFlowColors.accent,
                                decoration: TextDecoration.underline),
                          ),
                          const TextSpan(text: ' e a '),
                          TextSpan(
                            text: 'Política de Privacidade',
                            style: const TextStyle(
                                color: InkFlowColors.accent,
                                decoration: TextDecoration.underline),
                          ),
                          const TextSpan(text: ' da InkFlow'),
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
              onPressed: _isLoading ? null : _handleSubmit,
              isLoading: _isLoading,
            ),
            const SizedBox(height: 16),

            Center(
              child: Text.rich(
                TextSpan(
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                  children: [
                    const TextSpan(text: 'Já tem conta? '),
                    WidgetSpan(
                      child: GestureDetector(
                        onTap: () => context.go('/'),
                        child: const Text(
                          'Entrar',
                          style: TextStyle(color: InkFlowColors.accent, fontSize: 12),
                        ),
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

  // Substitui o InkTextField visual apenas para garantir que o TextFormField seja usado nativamente no Form
  Widget _buildValidatedField({
    required String label,
    required FormFieldValidator<String> validator,
    required FormFieldSetter<String> onSaved,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
              fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextFormField(
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        Text(
          'Data de nascimento *',
          style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
              fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isUnderage
                    ? const Color(0xFFEF4444).withOpacity(0.6)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Text(
                  dateStr,
                  style: TextStyle(
                    color: _selectedDob == null
                        ? Colors.white.withOpacity(0.3)
                        : Colors.white,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Icon(Icons.calendar_today, color: Colors.white.withOpacity(0.4), size: 16),
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
        color: const Color(0xFFEF4444).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.2)),
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
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: '000.000.000-00',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              errorStyle: const TextStyle(color: Color(0xFFEF4444)),
            ),
            validator: (v) {
              if (_isUnderage && (v == null || v.isEmpty)) return 'Obrigatório para menores';
              return null;
            },
            onSaved: (v) => _guardianCpf = v ?? '',
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
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: InkFlowColors.accent,
            onPrimary: InkFlowColors.primary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDob = picked;
      });
    }
  }
}