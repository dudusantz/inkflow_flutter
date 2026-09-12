import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:inkflow/core/errors/error_utils.dart';
import 'package:inkflow/core/theme/app_theme.dart';
import 'package:inkflow/core/widgets/shared_widgets.dart';
import 'package:inkflow/features/finance/data/finance_repository.dart';

class FiscalSettingsScreen extends ConsumerStatefulWidget {
  const FiscalSettingsScreen({super.key});

  @override
  ConsumerState<FiscalSettingsScreen> createState() =>
      _FiscalSettingsScreenState();
}

class _FiscalSettingsScreenState extends ConsumerState<FiscalSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _taxId = TextEditingController();
  final _legalName = TextEditingController();
  final _tradeName = TextEditingController();
  final _municipalRegistration = TextEditingController();
  final _address = TextEditingController();
  final _taxRate = TextEditingController();
  String _personType = 'PF';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ref.read(financeRepositoryProvider).getFiscalProfile();
      if (data != null) {
        _personType = data['person_type']?.toString() ?? 'PF';
        _taxId.text = data['tax_id']?.toString() ?? '';
        _legalName.text = data['legal_name']?.toString() ?? '';
        _tradeName.text = data['trade_name']?.toString() ?? '';
        _municipalRegistration.text =
            data['municipal_registration']?.toString() ?? '';
        _address.text = data['fiscal_address']?.toString() ?? '';
        _taxRate.text = data['tax_rate']?.toString() ?? '';
      }
    } catch (error) {
      if (mounted) showErrorSnackBar(context, userFriendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(financeRepositoryProvider).saveFiscalProfile({
        'person_type': _personType,
        'tax_id': _taxId.text.trim(),
        'legal_name': _legalName.text.trim(),
        'trade_name': _tradeName.text.trim(),
        'municipal_registration': _municipalRegistration.text.trim(),
        'fiscal_address': _address.text.trim(),
        'tax_rate': double.tryParse(_taxRate.text.replaceAll(',', '.')),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Dados fiscais salvos.'),
          backgroundColor: InkFlowColors.success,
        ));
      }
    } catch (error) {
      if (mounted) showErrorSnackBar(context, userFriendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _taxId.dispose();
    _legalName.dispose();
    _tradeName.dispose();
    _municipalRegistration.dispose();
    _address.dispose();
    _taxRate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      body: Column(
        children: [
          const AppHeader(
            title: 'Fiscal e recibos',
            showBack: true,
            backTo: '/studio-management',
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: InkFlowColors.accent))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7E8),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline,
                                    size: 20, color: Color(0xFF9A6500)),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Este cadastro prepara recibos e relatórios. A emissão oficial de NFS-e dependerá da integração com um provedor fiscal.',
                                    style: TextStyle(
                                        fontSize: 11,
                                        height: 1.35,
                                        color: Color(0xFF805A13)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text('Identificação fiscal',
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 12),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                  value: 'PF', label: Text('Pessoa física')),
                              ButtonSegment(
                                  value: 'PJ', label: Text('Pessoa jurídica')),
                            ],
                            selected: {_personType},
                            onSelectionChanged: (value) =>
                                setState(() => _personType = value.first),
                          ),
                          const SizedBox(height: 14),
                          _field(_taxId, _personType == 'PF' ? 'CPF' : 'CNPJ',
                              required: true),
                          _field(
                              _legalName,
                              _personType == 'PF'
                                  ? 'Nome completo'
                                  : 'Razão social',
                              required: true),
                          _field(_tradeName, 'Nome fantasia'),
                          _field(_municipalRegistration, 'Inscrição municipal'),
                          _field(_address, 'Endereço fiscal', maxLines: 2),
                          _field(_taxRate, 'Alíquota de referência (%)',
                              numeric: true),
                          const SizedBox(height: 8),
                          InkButton(
                            label: 'Salvar dados fiscais',
                            isLoading: _saving,
                            onPressed: _save,
                          ),
                          const SizedBox(height: 24),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.receipt_long_outlined,
                                    color: Color(0xFF167D7B), size: 30),
                                SizedBox(height: 8),
                                Text('Recibos digitais',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w800)),
                                SizedBox(height: 4),
                                Text(
                                  'A geração e exportação em PDF será a próxima etapa após o cadastro fiscal.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 11, color: Color(0xFF7B8491)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool numeric = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (value) => value == null || value.trim().isEmpty
                ? 'Campo obrigatório.'
                : null
            : null,
      ),
    );
  }
}
