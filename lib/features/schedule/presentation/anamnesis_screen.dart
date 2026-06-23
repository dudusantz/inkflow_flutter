import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inkflow/core/theme/app_theme.dart';
import 'package:inkflow/core/widgets/shared_widgets.dart';

class AnamnesisScreen extends StatefulWidget {
  const AnamnesisScreen({super.key});

  @override
  State<AnamnesisScreen> createState() => _AnamnesisScreenState();
}

class _AnamnesisScreenState extends State<AnamnesisScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _submitted = false;
  bool _isLoading = false;
  bool _termsError = false;

  bool? _hasAllergies;
  bool? _usesMedication;
  bool? _hasDisease;
  bool? _isPregnant;

  bool _anticoagulants = false;
  bool _diabetes = false;
  bool _heartCondition = false;
  bool _bloodDisorder = false;
  bool _terms = false;

  String _signature = '';
  String _allergyDetails = '';
  String _medicationDetails = '';
  String _diseaseDetails = '';

  bool get _hasRisk =>
      _anticoagulants ||
      _pregnantYes ||
      _bloodDisorder ||
      _heartCondition ||
      _diabetes;

  bool get _pregnantYes => _isPregnant == true;

  void _handleSubmit() async {
    setState(() => _termsError = false);

    if (!_terms) {
      setState(() => _termsError = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você precisa aceitar a declaração para enviar.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    if (_hasAllergies == null ||
        _usesMedication == null ||
        _hasDisease == null ||
        _isPregnant == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Responda todas as perguntas de saúde.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isLoading = true);

      try {
        await Future.delayed(const Duration(milliseconds: 1200));

        if (mounted) {
          setState(() {
            _isLoading = false;
            _submitted = true;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildSecureHeader(),
          Expanded(
            child: _submitted ? _buildResult() : _buildForm(),
          ),
        ],
      ),
    );
  }

  Widget _buildSecureHeader() {
    return Container(
      color: InkFlowColors.primary,
      padding: EdgeInsets.fromLTRB(
        8,
        MediaQuery.of(context).padding.top + 4,
        16,
        16,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 20),
            onPressed: () => context.go('/home'),
          ),
          const Icon(Icons.lock, color: InkFlowColors.accent, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ficha de Anamnese',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Dados protegidos e criptografados (LGPD)',
                  style: TextStyle(color: Color(0x99FFFFFF), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    if (_hasRisk) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning, color: Color(0xFFEF4444), size: 64),
            const SizedBox(height: 16),
            const Text(
              'Ficha enviada com Alerta Médico',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFFEF4444).withOpacity(0.2)),
              ),
              child: const Text(
                'Você informou condições de saúde críticas. Este procedimento exige laudo médico de liberação antes de prosseguir.',
                style: TextStyle(color: Color(0xFFDC2626), fontSize: 13),
              ),
            ),
            const SizedBox(height: 32),
            InkButton(
              label: 'Voltar para Agenda',
              onPressed: () => context.go('/schedule'),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_user, color: Color(0xFF10B981), size: 64),
          const SizedBox(height: 16),
          const Text(
            'Ficha enviada com segurança',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Assinatura digital registrada. Seus dados estão protegidos pela LGPD.',
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: InkButton(
              label: 'Voltar ao Início',
              onPressed: () => context.go('/home'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _yesNoQuestion(
              'Possui alergias conhecidas?',
              _hasAllergies,
              (v) => setState(() => _hasAllergies = v),
            ),
            if (_hasAllergies == true) ...[
              const SizedBox(height: 8),
              TextFormField(
                decoration: _inputDecoration('Detalhe suas alergias'),
                onSaved: (v) => _allergyDetails = v ?? '',
              ),
            ],
            const SizedBox(height: 16),
            _yesNoQuestion(
              'Faz uso de medicamentos?',
              _usesMedication,
              (v) => setState(() => _usesMedication = v),
            ),
            if (_usesMedication == true) ...[
              const SizedBox(height: 8),
              TextFormField(
                decoration: _inputDecoration('Quais medicamentos?'),
                onSaved: (v) => _medicationDetails = v ?? '',
              ),
            ],
            const SizedBox(height: 16),
            _yesNoQuestion(
              'Possui doenças pré-existentes?',
              _hasDisease,
              (v) => setState(() => _hasDisease = v),
            ),
            if (_hasDisease == true) ...[
              const SizedBox(height: 8),
              TextFormField(
                decoration: _inputDecoration('Descreva as condições'),
                onSaved: (v) => _diseaseDetails = v ?? '',
              ),
            ],
            const SizedBox(height: 16),
            _yesNoQuestion(
              'Está grávida ou amamentando?',
              _isPregnant,
              (v) => setState(() => _isPregnant = v),
            ),
            const SizedBox(height: 24),
            const Text(
              'Condições adicionais',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            _buildCheckbox(
              'Uso de anticoagulantes',
              _anticoagulants,
              (v) => setState(() => _anticoagulants = v!),
            ),
            _buildCheckbox(
              'Diabetes',
              _diabetes,
              (v) => setState(() => _diabetes = v!),
            ),
            _buildCheckbox(
              'Problemas cardíacos',
              _heartCondition,
              (v) => setState(() => _heartCondition = v!),
            ),
            _buildCheckbox(
              'Distúrbios de coagulação',
              _bloodDisorder,
              (v) => setState(() => _bloodDisorder = v!),
            ),
            const SizedBox(height: 24),
            const Text(
              'Assinatura Digital',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              decoration: _inputDecoration('Seu nome completo (Assinatura) *'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Assinatura obrigatória' : null,
              onSaved: (v) => _signature = v!,
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: _termsError
                    ? const Color(0xFFEF4444).withOpacity(0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _termsError
                      ? const Color(0xFFEF4444)
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: CheckboxListTile(
                title: const Text(
                  'Declaro que as informações são verdadeiras e estou ciente das implicações legais deste documento.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                value: _terms,
                onChanged: (v) => setState(() {
                  _terms = v ?? false;
                  _termsError = false;
                }),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                activeColor: InkFlowColors.accent,
              ),
            ),
            if (_termsError)
              const Padding(
                padding: EdgeInsets.only(left: 8, top: 4),
                child: Text(
                  'Aceite a declaração para continuar.',
                  style: TextStyle(color: Color(0xFFEF4444), fontSize: 11),
                ),
              ),
            const SizedBox(height: 24),
            InkButton(
              label: 'Assinar e Enviar',
              onPressed: _isLoading ? null : _handleSubmit,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _yesNoQuestion(
    String question,
    bool? value,
    ValueChanged<bool> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: RadioListTile<bool>(
                title: const Text('Sim', style: TextStyle(fontSize: 13)),
                value: true,
                groupValue: value,
                onChanged: (v) => onChanged(v!),
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: InkFlowColors.accent,
              ),
            ),
            Expanded(
              child: RadioListTile<bool>(
                title: const Text('Não', style: TextStyle(fontSize: 13)),
                value: false,
                groupValue: value,
                onChanged: (v) => onChanged(v!),
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: InkFlowColors.accent,
              ),
            ),
          ],
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildCheckbox(
    String title,
    bool value,
    void Function(bool?) onChanged,
  ) {
    return CheckboxListTile(
      title: Text(title, style: const TextStyle(fontSize: 14)),
      value: value,
      onChanged: onChanged,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}
