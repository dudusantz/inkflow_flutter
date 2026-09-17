import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:inkflow/core/theme/app_theme.dart';
import 'package:inkflow/core/widgets/shared_widgets.dart';

/// Ficha de anamnese (RF07) — **em desenvolvimento**.
///
/// O formulário valida as respostas, mas nada é enviado ao servidor: não existe
/// tabela nem política de acesso para dado de saúde, que a LGPD classifica como
/// sensível. A tela anterior anunciava "dados protegidos e criptografados
/// (LGPD)" enquanto descartava tudo no `Future.delayed` — a afirmação foi
/// removida até a persistência existir de fato.
class AnamnesisScreen extends StatefulWidget {
  const AnamnesisScreen({super.key});

  @override
  State<AnamnesisScreen> createState() => _AnamnesisScreenState();
}

class _AnamnesisScreenState extends State<AnamnesisScreen> {
  final _formKey = GlobalKey<FormState>();

  final _signatureController = TextEditingController();
  final _allergyController = TextEditingController();
  final _medicationController = TextEditingController();
  final _diseaseController = TextEditingController();

  bool _submitted = false;
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

  bool get _hasRisk =>
      _anticoagulants ||
      _isPregnant == true ||
      _bloodDisorder ||
      _heartCondition ||
      _diabetes;

  @override
  void dispose() {
    _signatureController.dispose();
    _allergyController.dispose();
    _medicationController.dispose();
    _diseaseController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: InkFlowColors.error,
      ),
    );
  }

  void _handleSubmit() {
    setState(() => _termsError = false);

    if (!_terms) {
      setState(() => _termsError = true);
      _showError('Você precisa aceitar a declaração para enviar.');
      return;
    }

    if (_hasAllergies == null ||
        _usesMedication == null ||
        _hasDisease == null ||
        _isPregnant == null) {
      _showError('Responda todas as perguntas de saúde.');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitted = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          const UnderDevelopmentBanner(
            message: 'Pré-visualização: as respostas não são enviadas nem '
                'armazenadas em nenhum servidor.',
          ),
          Expanded(child: _submitted ? _buildResult() : _buildForm()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
            tooltip: 'Voltar',
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/home'),
          ),
          const Expanded(
            child: Text(
              'Ficha de Anamnese',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            _hasRisk ? Icons.warning_amber_rounded : Icons.check_circle_outline,
            color: _hasRisk ? InkFlowColors.error : InkFlowColors.success,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            _hasRisk ? 'Respostas com alerta médico' : 'Respostas preenchidas',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (_hasRisk)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: InkFlowColors.error.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: InkFlowColors.error.withValues(alpha: 0.2)),
              ),
              child: const Text(
                'Você informou condições de saúde críticas. Este procedimento '
                'exige laudo médico de liberação antes de prosseguir.',
                style: TextStyle(color: Color(0xFFDC2626), fontSize: 13),
              ),
            ),
          const SizedBox(height: 24),
          _buildSummary(),
          const SizedBox(height: 32),
          InkButton(
            label: 'Voltar para a Agenda',
            onPressed: () => context.go('/schedule'),
          ),
        ],
      ),
    );
  }

  /// Resumo local do que foi preenchido. Deixa claro que a informação existe
  /// apenas nesta sessão.
  Widget _buildSummary() {
    final lines = <String>[
      'Assinatura: ${_signatureController.text.trim()}',
      if (_hasAllergies == true && _allergyController.text.trim().isNotEmpty)
        'Alergias: ${_allergyController.text.trim()}',
      if (_usesMedication == true &&
          _medicationController.text.trim().isNotEmpty)
        'Medicamentos: ${_medicationController.text.trim()}',
      if (_hasDisease == true && _diseaseController.text.trim().isNotEmpty)
        'Condições: ${_diseaseController.text.trim()}',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resumo desta sessão',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(line,
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF4B5563))),
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
                controller: _allergyController,
                decoration: _inputDecoration('Detalhe suas alergias'),
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
                controller: _medicationController,
                decoration: _inputDecoration('Quais medicamentos?'),
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
                controller: _diseaseController,
                decoration: _inputDecoration('Descreva as condições'),
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
            _buildCheckbox('Uso de anticoagulantes', _anticoagulants,
                (v) => setState(() => _anticoagulants = v)),
            _buildCheckbox(
                'Diabetes', _diabetes, (v) => setState(() => _diabetes = v)),
            _buildCheckbox('Problemas cardíacos', _heartCondition,
                (v) => setState(() => _heartCondition = v)),
            _buildCheckbox('Distúrbios de coagulação', _bloodDisorder,
                (v) => setState(() => _bloodDisorder = v)),
            const SizedBox(height: 24),
            const Text(
              'Assinatura',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _signatureController,
              decoration: _inputDecoration('Seu nome completo *'),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Assinatura obrigatória'
                  : null,
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: _termsError
                    ? InkFlowColors.error.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _termsError ? InkFlowColors.error : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: CheckboxListTile(
                title: const Text(
                  'Declaro que as informações são verdadeiras.',
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
                  style: TextStyle(color: InkFlowColors.error, fontSize: 11),
                ),
              ),
            const SizedBox(height: 24),
            InkButton(label: 'Revisar Respostas', onPressed: _handleSubmit),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Par Sim/Não como `SegmentedButton`.
  ///
  /// `RadioListTile.groupValue`/`onChanged` estão depreciados e quebram numa
  /// versão futura do Flutter.
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
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Sim')),
            ButtonSegment(value: false, label: Text('Não')),
          ],
          selected: value == null ? <bool>{} : {value},
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          onSelectionChanged: (selection) {
            if (selection.isNotEmpty) onChanged(selection.first);
          },
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
    ValueChanged<bool> onChanged,
  ) {
    return CheckboxListTile(
      title: Text(title, style: const TextStyle(fontSize: 14)),
      value: value,
      onChanged: (v) => onChanged(v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}
