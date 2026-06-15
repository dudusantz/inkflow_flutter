import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

enum AnamnesisScenario { success, noAccept, risk }

class AnamnesisScreen extends StatefulWidget {
  const AnamnesisScreen({super.key});

  @override
  State<AnamnesisScreen> createState() => _AnamnesisScreenState();
}

class _AnamnesisScreenState extends State<AnamnesisScreen> {
  AnamnesisScenario _scenario = AnamnesisScenario.success;
  bool _submitted = false;

  bool _anticoagulants = false;
  bool _pregnant = false;
  bool _diabetes = false;
  bool _heartCondition = false;
  bool _bloodDisorder = false;
  bool _terms = true;
  String _signature = 'Carlos Mendes';
  String _allergies = '';
  String _medications = '';

  bool get _hasRisk => _anticoagulants || _pregnant;
  bool get _canSubmit => _terms && _signature.trim().isNotEmpty;

  void _applyScenario(AnamnesisScenario s) {
    setState(() {
      _scenario = s;
      _submitted = false;
      switch (s) {
        case AnamnesisScenario.success:
          _terms = true;
          _anticoagulants = false;
          _pregnant = false;
          _signature = 'Carlos Mendes';
          break;
        case AnamnesisScenario.noAccept:
          _terms = false;
          _anticoagulants = false;
          _pregnant = false;
          _signature = 'Carlos Mendes';
          break;
        case AnamnesisScenario.risk:
          _terms = true;
          _anticoagulants = true;
          _signature = 'Carlos Mendes';
          break;
      }
    });
  }

  void _handleSubmit() {
    if (_canSubmit) setState(() => _submitted = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ScenarioSwitcher(
            rf: 'RF07',
            active: _scenario.name,
            scenarios: const [
              ScenarioConfig(key: 'success', label: '✓ Assinatura OK', color: ScenarioColor.green),
              ScenarioConfig(key: 'noAccept', label: '✗ Sem Aceite', color: ScenarioColor.red),
              ScenarioConfig(key: 'risk', label: '⚠ Condição de Risco', color: ScenarioColor.yellow),
            ],
            onChange: (k) => _applyScenario(
                AnamnesisScenario.values.firstWhere((e) => e.name == k)),
          ),

          AppHeader(title: 'Ficha de Anamnese', showBack: true, backTo: '/home'),

          if (_submitted)
            Expanded(child: _buildResult())
          else
            Expanded(child: _buildForm()),
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
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning, color: Color(0xFFEF4444), size: 40),
            ),
            const SizedBox(height: 16),
            const Text('Ficha enviada com Alerta Médico',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937)),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      const Text('🚨 Liberação Médica Necessária',
                          style: TextStyle(
                              color: Color(0xFFB91C1C),
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'O cliente informou uso de anticoagulantes. Este procedimento exige laudo médico de liberação antes de prosseguir.',
                    style: TextStyle(color: Color(0xFFDC2626), fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => context.go('/schedule'),
              style: ElevatedButton.styleFrom(
                backgroundColor: InkFlowColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Voltar para Agenda'),
            ),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified, color: Color(0xFF10B981), size: 40),
          ),
          const SizedBox(height: 16),
          const Text('Ficha Enviada!',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937))),
          const SizedBox(height: 8),
          Text('Assinatura digital registrada com sucesso.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF10B981).withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, color: Color(0xFF10B981), size: 14),
                const SizedBox(width: 6),
                Text(
                  'Dados protegidos — LGPD',
                  style: TextStyle(
                      color: const Color(0xFF10B981).withOpacity(0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => context.go('/home'),
            style: ElevatedButton.styleFrom(
              backgroundColor: InkFlowColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Voltar ao Início'),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: InkFlowColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: InkFlowColors.accent, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Preencha com atenção. As informações são confidenciais e protegidas por lei.',
                    style: TextStyle(
                        color: InkFlowColors.accent, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _sectionTitle('Histórico Médico'),
          const SizedBox(height: 8),
          _lightInput('Alergias conhecidas', 'Ex: Látex, penicilina...', (v) => _allergies = v, value: _allergies),
          const SizedBox(height: 10),
          _lightInput('Medicamentos em uso', 'Ex: Anticoagulantes, antidepressivos...', (v) => _medications = v, value: _medications),
          const SizedBox(height: 20),

          _sectionTitle('Condições de Saúde'),
          const SizedBox(height: 8),

          _checkItem('Uso de anticoagulantes', _anticoagulants, (v) {
            setState(() => _anticoagulants = v!);
          }, isRisk: true),
          _checkItem('Gravidez', _pregnant, (v) {
            setState(() => _pregnant = v!);
          }, isRisk: true),
          _checkItem('Diabetes', _diabetes, (v) {
            setState(() => _diabetes = v!);
          }),
          _checkItem('Problemas cardíacos', _heartCondition, (v) {
            setState(() => _heartCondition = v!);
          }),
          _checkItem('Distúrbios de coagulação', _bloodDisorder, (v) {
            setState(() => _bloodDisorder = v!);
          }),

          if (_hasRisk) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: Color(0xFFEF4444), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Condição de risco detectada. Pode ser necessário liberação médica.',
                      style: TextStyle(
                          color: Color(0xFFEF4444), fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),

          _sectionTitle('Assinatura Digital'),
          const SizedBox(height: 8),
          _lightInput('Nome completo (assinatura)', 'Seu nome completo', (v) => setState(() => _signature = v), value: _signature),
          const SizedBox(height: 16),

          // Aceite
          GestureDetector(
            onTap: () => setState(() => _terms = !_terms),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: !_terms && _scenario == AnamnesisScenario.noAccept
                    ? const Color(0xFFEF4444).withOpacity(0.05)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: !_terms && _scenario == AnamnesisScenario.noAccept
                      ? const Color(0xFFEF4444).withOpacity(0.4)
                      : Colors.grey.shade200,
                  width: !_terms && _scenario == AnamnesisScenario.noAccept ? 2 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _terms ? const Color(0xFF10B981) : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: !_terms && _scenario == AnamnesisScenario.noAccept
                            ? const Color(0xFFEF4444)
                            : _terms
                                ? const Color(0xFF10B981)
                                : Colors.grey.shade400,
                        width: 2,
                      ),
                    ),
                    child: _terms
                        ? const Icon(Icons.check, color: Colors.white, size: 12)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Declaro que as informações acima são verdadeiras e estou ciente das implicações legais deste documento.',
                      style: TextStyle(
                        fontSize: 12,
                        color: !_terms && _scenario == AnamnesisScenario.noAccept
                            ? const Color(0xFFEF4444)
                            : Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (!_terms && _scenario == AnamnesisScenario.noAccept) ...[
            const SizedBox(height: 6),
            const Text(
              '⚠ Você deve aceitar os termos para enviar a ficha',
              style: TextStyle(color: Color(0xFFEF4444), fontSize: 11),
            ),
          ],
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canSubmit ? _handleSubmit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _canSubmit ? InkFlowColors.primary : Colors.grey.shade200,
                foregroundColor:
                    _canSubmit ? Colors.white : Colors.grey.shade400,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                _canSubmit ? 'Enviar Ficha' : 'Aceite os termos para continuar',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text,
        style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)));
  }

  Widget _lightInput(String label, String hint, ValueChanged<String> onChanged, {String value = ''}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: value,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _checkItem(String label, bool value, ValueChanged<bool?> onChanged, {bool isRisk = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: isRisk ? const Color(0xFFEF4444) : InkFlowColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade800,
                fontWeight: isRisk && value ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          if (isRisk && value)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('Risco',
                  style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}
