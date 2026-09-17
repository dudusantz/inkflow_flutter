import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

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
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _postalCode = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _taxRate = TextEditingController();
  final _defaultService = TextEditingController();
  final _receiptNotes = TextEditingController();
  final _cpfMask = MaskTextInputFormatter(mask: '###.###.###-##');
  final _cnpjMask = MaskTextInputFormatter(mask: '##.###.###/####-##');
  final _cepMask = MaskTextInputFormatter(mask: '#####-###');
  final _phoneMask = MaskTextInputFormatter(mask: '(##) #####-####');
  String _personType = 'PF';
  bool _loading = true;
  bool _saving = false;
  bool _lookingUpCep = false;
  String? _lastCep;

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
        _taxId.text = _taxMask.maskText(data['tax_id']?.toString() ?? '');
        _legalName.text = data['legal_name']?.toString() ?? '';
        _tradeName.text = data['trade_name']?.toString() ?? '';
        _municipalRegistration.text =
            data['municipal_registration']?.toString() ?? '';
        _address.text = data['fiscal_address']?.toString() ?? '';
        _city.text = data['city']?.toString() ?? '';
        _state.text = data['state']?.toString() ?? '';
        _postalCode.text =
            _cepMask.maskText(data['postal_code']?.toString() ?? '');
        _email.text = data['email']?.toString() ?? '';
        _phone.text = _phoneMask.maskText(data['phone']?.toString() ?? '');
        _taxRate.text = data['tax_rate']?.toString() ?? '';
        _defaultService.text =
            data['default_service_description']?.toString() ?? '';
        _receiptNotes.text = data['receipt_notes']?.toString() ?? '';
      }
    } catch (error) {
      if (mounted) showErrorSnackBar(context, userFriendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  MaskTextInputFormatter get _taxMask =>
      _personType == 'PF' ? _cpfMask : _cnpjMask;

  void _changePersonType(String value) {
    final digits = _taxId.text.replaceAll(RegExp(r'\D'), '');
    setState(() {
      _personType = value;
      _taxId.text = _taxMask.maskText(digits);
    });
  }

  Future<void> _lookupCep(String value) async {
    final cep = value.replaceAll(RegExp(r'\D'), '');
    if (cep.length != 8 || cep == _lastCep) return;
    _lastCep = cep;
    setState(() => _lookingUpCep = true);
    try {
      final response = await http
          .get(Uri.parse('https://viacep.com.br/ws/$cep/json/'))
          .timeout(const Duration(seconds: 8));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || data['erro'] == true) {
        throw const FormatException('CEP não encontrado.');
      }
      if (!mounted) return;
      _address.text = [data['logradouro'], data['complemento'], data['bairro']]
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .join(', ');
      _city.text = data['localidade']?.toString() ?? '';
      _state.text = data['uf']?.toString() ?? '';
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível localizar o CEP.')),
        );
      }
    } finally {
      if (mounted) setState(() => _lookingUpCep = false);
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
        'city': _city.text.trim(),
        'state': _state.text.trim().toUpperCase(),
        'postal_code': _postalCode.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'tax_rate': double.tryParse(_taxRate.text.replaceAll(',', '.')),
        'default_service_description': _defaultService.text.trim(),
        'receipt_notes': _receiptNotes.text.trim(),
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
    _city.dispose();
    _state.dispose();
    _postalCode.dispose();
    _email.dispose();
    _phone.dispose();
    _taxRate.dispose();
    _defaultService.dispose();
    _receiptNotes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      body: Column(
        children: [
          const AppHeader(
            title: 'Dados do estúdio e recibos',
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
                                _changePersonType(value.first),
                          ),
                          const SizedBox(height: 14),
                          _field(_taxId, _personType == 'PF' ? 'CPF' : 'CNPJ',
                              required: true,
                              numeric: true,
                              inputFormatters: [_taxMask]),
                          _field(
                              _legalName,
                              _personType == 'PF'
                                  ? 'Nome completo'
                                  : 'Razão social',
                              required: true),
                          _field(_tradeName, 'Nome fantasia'),
                          _field(_municipalRegistration, 'Inscrição municipal'),
                          _field(
                            _postalCode,
                            'CEP',
                            numeric: true,
                            inputFormatters: [_cepMask],
                            onChanged: _lookupCep,
                            suffixIcon: _lookingUpCep
                                ? const Padding(
                                    padding: EdgeInsets.all(14),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: InkFlowColors.accent,
                                    ),
                                  )
                                : null,
                          ),
                          _field(_address, 'Endereço fiscal', maxLines: 2),
                          Row(
                            children: [
                              Expanded(child: _field(_city, 'Cidade')),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 90,
                                child: _field(
                                  _state,
                                  'UF',
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(2),
                                    UpperCaseTextFormatter(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          _field(_email, 'E-mail profissional',
                              keyboardType: TextInputType.emailAddress),
                          _field(
                            _phone,
                            'Telefone profissional',
                            numeric: true,
                            inputFormatters: [_phoneMask],
                          ),
                          _field(_taxRate, 'Alíquota de referência (%)',
                              numeric: true),
                          const SizedBox(height: 8),
                          const Text('Preferências do recibo',
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 12),
                          _field(_defaultService, 'Descrição padrão do serviço',
                              maxLines: 2),
                          _field(_receiptNotes, 'Observações padrão',
                              maxLines: 3),
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
                                Text('Documentos de serviço',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w800)),
                                SizedBox(height: 4),
                                Text(
                                  'Os PDFs seguem um modelo fiscal com a identidade do InkFlow. A NFS-e oficial ainda depende de integração municipal.',
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
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
    Widget? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType ??
            (numeric
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text),
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label, suffixIcon: suffixIcon),
        validator: required
            ? (value) => value == null || value.trim().isEmpty
                ? 'Campo obrigatório.'
                : null
            : null,
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
