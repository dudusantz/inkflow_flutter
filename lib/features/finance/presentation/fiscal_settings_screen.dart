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
            dark: true,
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
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF183638), Color(0xFF244A4B)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: InkFlowColors.accent
                                        .withValues(alpha: .16),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: const Icon(Icons.receipt_long_outlined,
                                      size: 22, color: Color(0xFF63CCC7)),
                                ),
                                const SizedBox(width: 13),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Identidade do seu estúdio',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800)),
                                      SizedBox(height: 5),
                                      Text(
                                        'Esses dados serão usados automaticamente nos recibos e relatórios.',
                                        style: TextStyle(
                                            fontSize: 11,
                                            height: 1.35,
                                            color: Color(0xFFC4D0D0)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          _sectionCard(
                            number: '1',
                            title: 'Identificação fiscal',
                            subtitle: 'Dados legais do profissional ou estúdio',
                            icon: Icons.badge_outlined,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: SegmentedButton<String>(
                                  segments: const [
                                    ButtonSegment(
                                        value: 'PF',
                                        icon: Icon(Icons.person_outline),
                                        label: Text('Pessoa física')),
                                    ButtonSegment(
                                        value: 'PJ',
                                        icon: Icon(Icons.storefront_outlined),
                                        label: Text('Pessoa jurídica')),
                                  ],
                                  selected: {_personType},
                                  onSelectionChanged: (value) =>
                                      _changePersonType(value.first),
                                  style: const ButtonStyle(
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              _field(
                                  _taxId, _personType == 'PF' ? 'CPF' : 'CNPJ',
                                  required: true,
                                  numeric: true,
                                  inputFormatters: [_taxMask],
                                  icon: Icons.fingerprint),
                              _field(
                                  _legalName,
                                  _personType == 'PF'
                                      ? 'Nome completo'
                                      : 'Razão social',
                                  required: true,
                                  icon: Icons.person_outline),
                              _field(_tradeName, 'Nome fantasia',
                                  icon: Icons.store_outlined),
                              _field(
                                  _municipalRegistration, 'Inscrição municipal',
                                  icon: Icons.article_outlined),
                              _field(_taxRate, 'Alíquota de referência (%)',
                                  numeric: true, icon: Icons.percent_rounded),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _sectionCard(
                            number: '2',
                            title: 'Endereço e contato',
                            subtitle: 'Informações exibidas nos documentos',
                            icon: Icons.location_on_outlined,
                            children: [
                              _field(
                                _postalCode,
                                'CEP',
                                numeric: true,
                                inputFormatters: [_cepMask],
                                onChanged: _lookupCep,
                                icon: Icons.local_post_office_outlined,
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
                              _field(_address, 'Endereço fiscal',
                                  maxLines: 2, icon: Icons.home_work_outlined),
                              Row(
                                children: [
                                  Expanded(child: _field(_city, 'Cidade')),
                                  const SizedBox(width: 10),
                                  SizedBox(
                                    width: 86,
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
                                  keyboardType: TextInputType.emailAddress,
                                  icon: Icons.alternate_email_rounded),
                              _field(
                                _phone,
                                'Telefone profissional',
                                numeric: true,
                                inputFormatters: [_phoneMask],
                                icon: Icons.phone_outlined,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _sectionCard(
                            number: '3',
                            title: 'Preferências do recibo',
                            subtitle: 'Textos preenchidos automaticamente',
                            icon: Icons.description_outlined,
                            children: [
                              _field(_defaultService,
                                  'Descrição padrão do serviço',
                                  maxLines: 2,
                                  icon: Icons.design_services_outlined),
                              _field(_receiptNotes, 'Observações padrão',
                                  maxLines: 3, icon: Icons.notes_rounded),
                            ],
                          ),
                          const SizedBox(height: 18),
                          InkButton(
                              label: 'Salvar configurações',
                              isLoading: _saving,
                              onPressed: _save),
                          const SizedBox(height: 12),
                          const Center(
                            child: Text(
                              'Documentos do InkFlow não substituem a NFS-e oficial.',
                              style: TextStyle(
                                  fontSize: 10, color: Color(0xFF7B8491)),
                            ),
                          ),
                          const SizedBox(height: 20),
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
    IconData? icon,
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
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon == null ? null : Icon(icon, size: 19),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: const Color(0xFFF8F9FA),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE1E5E8)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: InkFlowColors.accent, width: 1.4),
          ),
        ),
        validator: required
            ? (value) => value == null || value.trim().isEmpty
                ? 'Campo obrigatório.'
                : null
            : null,
      ),
    );
  }

  Widget _sectionCard({
    required String number,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE3E7E9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: InkFlowColors.accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF167D7B), size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$number. $title',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF7B8491))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
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
