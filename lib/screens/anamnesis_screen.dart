import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class AnamnesisScreen extends StatefulWidget {
  const AnamnesisScreen({super.key});

  @override
  State<AnamnesisScreen> createState() => _AnamnesisScreenState();
}

class _AnamnesisScreenState extends State<AnamnesisScreen> {
  final _formKey = GlobalKey<FormState>();
  
  bool _submitted = false;
  bool _isLoading = false;

  bool _anticoagulants = false;
  bool _pregnant = false;
  bool _diabetes = false;
  bool _heartCondition = false;
  bool _bloodDisorder = false;
  bool _terms = false;
  
  String _signature = '';
  String _allergies = '';
  String _medications = '';

  // Regra de negócio: Define se a ficha requer liberação médica (RF07)
  bool get _hasRisk => _anticoagulants || _pregnant || _bloodDisorder || _heartCondition;

  void _handleSubmit() async {
    if (!_terms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Você precisa aceitar os termos legais.'), backgroundColor: Color(0xFFEF4444)),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isLoading = true);

      try {
        // TODO: Enviar dados criptografados para o banco (RNF01 - LGPD)
        // await anamnesisService.submitFicha(...)
        await Future.delayed(const Duration(milliseconds: 1500)); // Simula rede

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
          AppHeader(title: 'Ficha de Anamnese', showBack: true, backTo: '/home'),
          Expanded(
            child: _submitted ? _buildResult() : _buildForm(),
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
            const Text('Ficha enviada com Alerta Médico',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.2)),
              ),
              child: const Text(
                'Você informou condições de saúde críticas. Este procedimento exige laudo médico de liberação antes de prosseguir.',
                style: TextStyle(color: Color(0xFFDC2626), fontSize: 13),
              ),
            ),
            const SizedBox(height: 32),
            InkButton(label: 'Voltar para Agenda', onPressed: () => context.go('/schedule')),
          ],
        ),
      );
    }
    
    // Sucesso sem risco
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified, color: Color(0xFF10B981), size: 64),
          const SizedBox(height: 16),
          const Text('Ficha Enviada!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Assinatura digital registrada com sucesso protegida pela LGPD.'),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: InkButton(label: 'Voltar ao Início', onPressed: () => context.go('/home')),
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
            // Histórico Médico
            const Text('Histórico Médico', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextFormField(
              decoration: _inputDecoration('Alergias conhecidas (Ex: Látex...)'),
              onSaved: (v) => _allergies = v ?? '',
            ),
            const SizedBox(height: 10),
            TextFormField(
              decoration: _inputDecoration('Medicamentos em uso'),
              onSaved: (v) => _medications = v ?? '',
            ),
            const SizedBox(height: 24),

            // Condições de Saúde (Checkboxes)
            const Text('Condições de Saúde', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            _buildCheckbox('Uso de anticoagulantes', _anticoagulants, (v) => setState(() => _anticoagulants = v!)),
            _buildCheckbox('Gravidez', _pregnant, (v) => setState(() => _pregnant = v!)),
            _buildCheckbox('Diabetes', _diabetes, (v) => setState(() => _diabetes = v!)),
            _buildCheckbox('Problemas cardíacos', _heartCondition, (v) => setState(() => _heartCondition = v!)),
            _buildCheckbox('Distúrbios de coagulação', _bloodDisorder, (v) => setState(() => _bloodDisorder = v!)),
            const SizedBox(height: 24),

            // Assinatura Digital
            const Text('Assinatura Digital', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextFormField(
              decoration: _inputDecoration('Seu nome completo (Assinatura) *'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Assinatura obrigatória' : null,
              onSaved: (v) => _signature = v!,
            ),
            const SizedBox(height: 16),

            // Aceite
            CheckboxListTile(
              title: const Text(
                'Declaro que as informações acima são verdadeiras e estou ciente das implicações legais deste documento.',
                style: TextStyle(fontSize: 12),
              ),
              value: _terms,
              onChanged: (v) => setState(() => _terms = v!),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: InkFlowColors.accent,
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

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    );
  }

  Widget _buildCheckbox(String title, bool value, void Function(bool?) onChanged) {
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