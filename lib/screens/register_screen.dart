import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

enum RegisterScenario { positive, underage, duplicate }

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  RegisterScenario _scenario = RegisterScenario.positive;
  bool _submitted = false;
  bool _isLoading = false;

  String _name = 'Marcos Silva';
  String _email = 'marcos.novo@email.com';
  String _cpf = '123.456.789-00';
  String _dob = '1995-06-20';
  String _password = 'Senha@123';
  String _guardianCpf = '';
  bool _terms = false;

  int get _age {
    if (_dob.isEmpty) return 99;
    try {
      final parts = _dob.split('-');
      final birth = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      final today = DateTime.now();
      int age = today.year - birth.year;
      if (today.month < birth.month ||
          (today.month == birth.month && today.day < birth.day)) {
        age--;
      }
      return age;
    } catch (_) {
      return 99;
    }
  }

  bool get _isUnderage => _age < 18;
  bool get _isDuplicate => _scenario == RegisterScenario.duplicate;
  bool get _canSubmit => !_isUnderage && _terms && !_isDuplicate;

  void _applyScenario(RegisterScenario s) {
    setState(() {
      _scenario = s;
      _submitted = false;
      switch (s) {
        case RegisterScenario.positive:
          _dob = '1995-06-20';
          _email = 'marcos.novo@email.com';
          _terms = false;
          _guardianCpf = '';
          break;
        case RegisterScenario.underage:
          _dob = '2010-03-15';
          _terms = false;
          _guardianCpf = '';
          break;
        case RegisterScenario.duplicate:
          _dob = '1995-06-20';
          _email = 'marcos@inkflow.com';
          _terms = true;
          break;
      }
    });
  }

  void _handleSubmit() async {
    if (!_canSubmit) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() {
        _isLoading = false;
        _submitted = true;
      });
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InkFlowColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            ScenarioSwitcher(
              rf: 'RF01',
              active: _scenario.name,
              scenarios: const [
                ScenarioConfig(key: 'positive', label: '✓ Positivo', color: ScenarioColor.green),
                ScenarioConfig(key: 'underage', label: '✗ Menor de Idade', color: ScenarioColor.red),
                ScenarioConfig(key: 'duplicate', label: '⚠ Duplicado', color: ScenarioColor.yellow),
              ],
              onChange: (k) => _applyScenario(
                RegisterScenario.values.firstWhere((e) => e.name == k),
              ),
            ),

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Aviso de duplicado
          if (_isDuplicate)
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

          InkTextField(
            label: 'Nome completo *',
            initialValue: _name,
            onChanged: (v) => _name = v,
          ),
          const SizedBox(height: 16),

          InkTextField(
            label: 'E-mail *',
            initialValue: _email,
            keyboardType: TextInputType.emailAddress,
            onChanged: (v) => setState(() => _email = v),
            hasError: _isDuplicate,
          ),
          const SizedBox(height: 16),

          InkTextField(
            label: 'CPF *',
            initialValue: _cpf,
            onChanged: (v) => _cpf = v,
          ),
          const SizedBox(height: 16),

          // Data de nascimento
          _dobField(),
          const SizedBox(height: 16),

          // Campo do responsável legal
          if (_isUnderage) _guardianField(),

          InkTextField(
            label: 'Senha *',
            initialValue: _password,
            obscureText: true,
            onChanged: (v) => _password = v,
          ),
          const SizedBox(height: 20),

          // Termos
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
            label: _isUnderage
                ? 'Bloqueado — Inclua o CPF do Responsável'
                : _isDuplicate
                    ? 'Cadastro Bloqueado'
                    : 'Criar Conta',
            onPressed: _canSubmit ? _handleSubmit : null,
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
                        style: TextStyle(
                            color: InkFlowColors.accent,
                            fontSize: 12),
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
    );
  }

  Widget _dobField() {
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
        const SizedBox(height: 4),
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
                    : Colors.white.withOpacity(0.1),
              ),
            ),
            child: Row(
              children: [
                Text(
                  _dob.isEmpty ? 'Selecionar data' : _dob,
                  style: TextStyle(
                    color: _dob.isEmpty
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
          const SizedBox(height: 4),
          Text(
            'Você possui $_age anos. Menores de 18 anos precisam incluir o CPF de um responsável legal.',
            style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11),
          ),
        ],
      ],
    );
  }

  Widget _guardianField() {
    return Column(
      children: [
        Container(
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
                initialValue: _guardianCpf,
                onChanged: (v) => setState(() => _guardianCpf = v),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '000.000.000-00',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: const Color(0xFFEF4444).withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: const Color(0xFFEF4444).withOpacity(0.3)),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1995, 6, 20),
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
        _dob = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }
}
