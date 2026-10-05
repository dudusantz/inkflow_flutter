import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import 'package:inkflow/core/errors/error_utils.dart';
import 'package:inkflow/core/theme/app_theme.dart';
import 'package:inkflow/core/widgets/shared_widgets.dart';
import 'package:inkflow/features/schedule/data/appointment_repository.dart';
import 'package:inkflow/features/schedule/presentation/schedule_screen.dart';

class AnamnesisScreen extends ConsumerStatefulWidget {
  final String proposalId;

  const AnamnesisScreen({super.key, required this.proposalId});

  @override
  ConsumerState<AnamnesisScreen> createState() => _AnamnesisScreenState();
}

class _AnamnesisScreenState extends ConsumerState<AnamnesisScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneMask = MaskTextInputFormatter(mask: '(##) #####-####');
  final _signatureController = TextEditingController();
  final _allergyController = TextEditingController();
  final _medicationController = TextEditingController();
  final _diseaseController = TextEditingController();
  final _skinController = TextEditingController();
  final _recentProcedureController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  bool _submitted = false;
  bool _isSaving = false;
  bool _showAnswerErrors = false;
  bool _termsError = false;
  bool _terms = false;

  bool? _hasAllergies;
  bool? _usesMedication;
  bool? _hasDisease;
  bool? _isPregnant;
  bool? _hasSkinCondition;
  bool? _hasHealingIssue;
  bool? _hasFaintingHistory;
  bool? _isImmunosuppressed;
  bool? _hadRecentProcedure;

  bool _anticoagulants = false;
  bool _diabetes = false;
  bool _heartCondition = false;
  bool _bloodDisorder = false;

  List<bool?> get _requiredAnswers => [
        _hasAllergies,
        _usesMedication,
        _hasDisease,
        _isPregnant,
        _hasSkinCondition,
        _hasHealingIssue,
        _hasFaintingHistory,
        _isImmunosuppressed,
        _hadRecentProcedure,
      ];

  bool get _hasRisk =>
      _anticoagulants ||
      _diabetes ||
      _heartCondition ||
      _bloodDisorder ||
      _isPregnant == true ||
      _hasSkinCondition == true ||
      _hasHealingIssue == true ||
      _hasFaintingHistory == true ||
      _isImmunosuppressed == true ||
      _hadRecentProcedure == true;

  @override
  void dispose() {
    _signatureController.dispose();
    _allergyController.dispose();
    _medicationController.dispose();
    _diseaseController.dispose();
    _skinController.dispose();
    _recentProcedureController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: InkFlowColors.error),
    );
  }

  void _handleSubmit() {
    setState(() {
      _showAnswerErrors = true;
      _termsError = !_terms;
    });
    if (_requiredAnswers.any((answer) => answer == null)) {
      _showError('Responda todas as perguntas antes de continuar.');
      return;
    }
    if (!_terms) {
      _showError('Você precisa aceitar a declaração para continuar.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitted = true);
  }

  Future<void> _confirmAcceptance() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(appointmentRepositoryProvider).acceptProposalWithAnamnesis(
        proposalId: widget.proposalId,
        signatureName: _signatureController.text.trim(),
        answers: {
          'hasAllergies': _hasAllergies,
          'allergies': _allergyController.text.trim(),
          'usesMedication': _usesMedication,
          'medications': _medicationController.text.trim(),
          'hasDisease': _hasDisease,
          'diseases': _diseaseController.text.trim(),
          'isPregnantOrBreastfeeding': _isPregnant,
          'hasSkinCondition': _hasSkinCondition,
          'skinConditionDetails': _skinController.text.trim(),
          'hasHealingIssue': _hasHealingIssue,
          'hasFaintingHistory': _hasFaintingHistory,
          'isImmunosuppressed': _isImmunosuppressed,
          'hadRecentProcedure': _hadRecentProcedure,
          'recentProcedureDetails': _recentProcedureController.text.trim(),
          'usesAnticoagulants': _anticoagulants,
          'hasDiabetes': _diabetes,
          'hasHeartCondition': _heartCondition,
          'hasBloodDisorder': _bloodDisorder,
          'emergencyContactName': _emergencyNameController.text.trim(),
          'emergencyContactPhone': _emergencyPhoneController.text.trim(),
          'acceptedDeclaration': _terms,
        },
      );
      ref.invalidate(scheduleProvider);
      if (mounted) context.pop(true);
    } on AppointmentConflictException {
      if (mounted) {
        _showError(
            'Este horário acabou de ser ocupado. Peça uma nova proposta.');
      }
    } on ProposalAcceptanceException catch (error) {
      if (mounted) _showError(error.message);
    } catch (error) {
      if (mounted) _showError(userFriendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: Text(_submitted ? 'Revisar anamnese' : 'Ficha de anamnese'),
      ),
      body: _submitted ? _buildReview() : _buildForm(),
      bottomNavigationBar:
          _submitted ? _buildReviewFooter() : _buildFormFooter(),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIntro(),
            const SizedBox(height: 20),
            _sectionCard(
              icon: Icons.health_and_safety_outlined,
              title: 'Saúde geral',
              description:
                  'Informe condições que podem alterar os cuidados da sessão.',
              children: [
                _question('Possui alergias conhecidas?', _hasAllergies,
                    (value) => setState(() => _hasAllergies = value)),
                if (_hasAllergies == true)
                  _detailsField(
                    _allergyController,
                    'Quais alergias?',
                    'Informe suas alergias',
                  ),
                _divider(),
                _question('Faz uso contínuo de medicamentos?', _usesMedication,
                    (value) => setState(() => _usesMedication = value)),
                if (_usesMedication == true)
                  _detailsField(
                    _medicationController,
                    'Quais medicamentos?',
                    'Informe os medicamentos',
                  ),
                _divider(),
                _question(
                    'Possui doença ou condição pré-existente?',
                    _hasDisease,
                    (value) => setState(() => _hasDisease = value)),
                if (_hasDisease == true)
                  _detailsField(
                    _diseaseController,
                    'Descreva a condição',
                    'Descreva a condição',
                  ),
                _divider(),
                _question('Está grávida ou amamentando?', _isPregnant,
                    (value) => setState(() => _isPregnant = value)),
              ],
            ),
            const SizedBox(height: 14),
            _sectionCard(
              icon: Icons.healing_outlined,
              title: 'Pele e cicatrização',
              description:
                  'Ajude o artista a avaliar a segurança do procedimento.',
              children: [
                _question(
                    'Possui irritação, ferida ou condição de pele na região?',
                    _hasSkinCondition,
                    (value) => setState(() => _hasSkinCondition = value)),
                if (_hasSkinCondition == true)
                  _detailsField(
                    _skinController,
                    'Descreva a condição e a região',
                    'Descreva a condição da pele',
                  ),
                _divider(),
                _question(
                    'Já teve queloide ou dificuldade de cicatrização?',
                    _hasHealingIssue,
                    (value) => setState(() => _hasHealingIssue = value)),
                _divider(),
                _question(
                    'Já teve desmaio, convulsão ou mal-estar em procedimentos?',
                    _hasFaintingHistory,
                    (value) => setState(() => _hasFaintingHistory = value)),
                _divider(),
                _question(
                    'Possui baixa imunidade ou faz tratamento imunossupressor?',
                    _isImmunosuppressed,
                    (value) => setState(() => _isImmunosuppressed = value)),
                _divider(),
                _question(
                    'Fez cirurgia ou procedimento médico nos últimos 6 meses?',
                    _hadRecentProcedure,
                    (value) => setState(() => _hadRecentProcedure = value)),
                if (_hadRecentProcedure == true)
                  _detailsField(
                    _recentProcedureController,
                    'Qual procedimento e quando?',
                    'Informe o procedimento recente',
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _sectionCard(
              icon: Icons.fact_check_outlined,
              title: 'Condições importantes',
              description: 'Marque apenas as opções que se aplicam a você.',
              children: [
                _condition('Uso de anticoagulantes', _anticoagulants,
                    (value) => setState(() => _anticoagulants = value)),
                _condition('Diabetes', _diabetes,
                    (value) => setState(() => _diabetes = value)),
                _condition('Problemas cardíacos', _heartCondition,
                    (value) => setState(() => _heartCondition = value)),
                _condition(
                  'Distúrbios de coagulação',
                  _bloodDisorder,
                  (value) => setState(() => _bloodDisorder = value),
                  last: true,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _sectionCard(
              icon: Icons.contact_phone_outlined,
              title: 'Contato de emergência',
              description:
                  'Opcional. Será usado apenas se houver necessidade durante a sessão.',
              children: [
                TextFormField(
                  controller: _emergencyNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration:
                      const InputDecoration(labelText: 'Nome do contato'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emergencyPhoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [_phoneMask],
                  decoration: const InputDecoration(labelText: 'Telefone'),
                  validator: (value) {
                    final hasName =
                        _emergencyNameController.text.trim().isNotEmpty;
                    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                    if (hasName && digits.length < 10) {
                      return 'Informe um telefone válido';
                    }
                    if (!hasName && digits.isNotEmpty) {
                      return 'Informe o nome do contato';
                    }
                    return null;
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            _sectionCard(
              icon: Icons.draw_outlined,
              title: 'Declaração e assinatura',
              description:
                  'Digite seu nome completo como assinatura eletrônica.',
              children: [
                TextFormField(
                  controller: _signatureController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nome completo *',
                    hintText: 'Como consta no documento',
                  ),
                  validator: (value) => value == null || value.trim().length < 3
                      ? 'Informe seu nome completo'
                      : null,
                ),
                const SizedBox(height: 14),
                _buildDeclaration(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: InkFlowColors.accent.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBox(icon: Icons.lock_outline_rounded),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sua segurança vem primeiro',
                  style: TextStyle(
                    color: InkFlowColors.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.25,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Leva cerca de 3 minutos. As respostas ficam disponíveis apenas para você e o tatuador responsável.',
                  style: TextStyle(
                    color: InkFlowColors.textMuted,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required String description,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: InkFlowColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: InkFlowColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBox(icon: icon, compact: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: InkFlowColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: const TextStyle(
                        color: InkFlowColors.textMuted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _question(
    String label,
    bool? value,
    ValueChanged<bool> onChanged,
  ) {
    final hasError = _showAnswerErrors && value == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: InkFlowColors.text,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _answerButton(
                label: 'Sim',
                selected: value == true,
                onTap: () => onChanged(true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _answerButton(
                label: 'Não',
                selected: value == false,
                onTap: () => onChanged(false),
              ),
            ),
          ],
        ),
        if (hasError)
          const Padding(
            padding: EdgeInsets.only(top: 7),
            child: Text(
              'Selecione uma resposta',
              style: TextStyle(color: InkFlowColors.error, fontSize: 11),
            ),
          ),
      ],
    );
  }

  Widget _answerButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected
          ? InkFlowColors.accent.withValues(alpha: .17)
          : InkFlowColors.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? InkFlowColors.accentDark : InkFlowColors.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (selected) ...[
                const Icon(Icons.check_rounded,
                    size: 17, color: InkFlowColors.accentDark),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  color:
                      selected ? InkFlowColors.accentDark : InkFlowColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailsField(
    TextEditingController controller,
    String label,
    String error,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: TextFormField(
        controller: controller,
        minLines: 2,
        maxLines: 4,
        decoration: InputDecoration(labelText: label, alignLabelWithHint: true),
        validator: (value) =>
            value == null || value.trim().isEmpty ? error : null,
      ),
    );
  }

  Widget _divider() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Divider(),
      );

  Widget _condition(
    String title,
    bool value,
    ValueChanged<bool> onChanged, {
    bool last = false,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Checkbox(
                  value: value,
                  onChanged: (checked) => onChanged(checked ?? false),
                  activeColor: InkFlowColors.accentDark,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: InkFlowColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!last) const Divider(indent: 48),
      ],
    );
  }

  Widget _buildDeclaration() {
    return InkWell(
      onTap: () => setState(() {
        _terms = !_terms;
        _termsError = false;
      }),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
        decoration: BoxDecoration(
          color: _termsError
              ? InkFlowColors.error.withValues(alpha: .06)
              : InkFlowColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _termsError ? InkFlowColors.error : InkFlowColors.border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _terms,
              onChanged: (value) => setState(() {
                _terms = value ?? false;
                _termsError = false;
              }),
              activeColor: InkFlowColors.accentDark,
            ),
            const SizedBox(width: 5),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 7),
                child: Text(
                  'Declaro que as informações são verdadeiras e me comprometo a comunicar qualquer mudança antes da sessão.',
                  style: TextStyle(
                    color: InkFlowColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormFooter() => _Footer(
        child: InkButton(label: 'Revisar respostas', onPressed: _handleSubmit),
      );

  Widget _buildReview() {
    final tone = _hasRisk ? InkFlowColors.warning : InkFlowColors.accentDark;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: tone.withValues(alpha: .11),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _IconBox(
                  icon: _hasRisk
                      ? Icons.info_outline_rounded
                      : Icons.check_circle_outline_rounded,
                  color: tone,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _hasRisk ? 'Revisão necessária' : 'Tudo preenchido',
                        style: const TextStyle(
                          color: InkFlowColors.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _hasRisk
                            ? 'Há respostas que o tatuador deverá avaliar antes da sessão.'
                            : 'Confira os dados antes de assinar e aceitar a proposta.',
                        style: const TextStyle(
                          color: InkFlowColors.textMuted,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _buildSummary(),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final conditions = <String>[
      if (_anticoagulants) 'Anticoagulantes',
      if (_diabetes) 'Diabetes',
      if (_heartCondition) 'Problemas cardíacos',
      if (_bloodDisorder) 'Distúrbios de coagulação',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: InkFlowColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: InkFlowColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumo das respostas',
            style: TextStyle(
              color: InkFlowColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 15),
          _summary('Alergias',
              _answerWithDetail(_hasAllergies, _allergyController.text)),
          _summary('Medicamentos',
              _answerWithDetail(_usesMedication, _medicationController.text)),
          _summary('Condição pré-existente',
              _answerWithDetail(_hasDisease, _diseaseController.text)),
          _summary('Gravidez ou amamentação', _yesNo(_isPregnant)),
          _summary('Condição de pele',
              _answerWithDetail(_hasSkinCondition, _skinController.text)),
          _summary('Cicatrização difícil', _yesNo(_hasHealingIssue)),
          _summary('Desmaio ou convulsão', _yesNo(_hasFaintingHistory)),
          _summary('Baixa imunidade', _yesNo(_isImmunosuppressed)),
          _summary(
              'Procedimento recente',
              _answerWithDetail(
                  _hadRecentProcedure, _recentProcedureController.text)),
          _summary('Outras condições',
              conditions.isEmpty ? 'Nenhuma informada' : conditions.join(', ')),
          if (_emergencyNameController.text.trim().isNotEmpty)
            _summary('Contato de emergência',
                '${_emergencyNameController.text.trim()} · ${_emergencyPhoneController.text.trim()}'),
          const Divider(height: 28),
          _summary('Assinatura', _signatureController.text.trim(), last: true),
        ],
      ),
    );
  }

  String _yesNo(bool? value) => value == true ? 'Sim' : 'Não';

  String _answerWithDetail(bool? value, String detail) =>
      value == true ? 'Sim · ${detail.trim()}' : 'Não';

  Widget _summary(String label, String value, {bool last = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(label,
                style: const TextStyle(
                    color: InkFlowColors.textMuted, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: InkFlowColors.text,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewFooter() => _Footer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkButton(
              label: 'Assinar e aceitar proposta',
              isLoading: _isSaving,
              onPressed: _confirmAcceptance,
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed:
                  _isSaving ? null : () => setState(() => _submitted = false),
              child: const Text('Editar respostas'),
            ),
          ],
        ),
      );
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool compact;

  const _IconBox({
    required this.icon,
    this.color = InkFlowColors.accentDark,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = compact ? 36.0 : 42.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(compact ? 11 : 13),
      ),
      child: Icon(icon, color: color, size: compact ? 19 : 21),
    );
  }
}

class _Footer extends StatelessWidget {
  final Widget child;

  const _Footer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: InkFlowColors.background,
        border: Border(top: BorderSide(color: InkFlowColors.border)),
      ),
      child: child,
    );
  }
}
