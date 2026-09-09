import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inkflow/core/data/brazil_locations_repository.dart';
import 'package:inkflow/core/errors/error_utils.dart';
import 'package:inkflow/core/theme/app_theme.dart';
import 'package:inkflow/core/widgets/shared_widgets.dart';
import 'package:inkflow/features/profile/data/profile_repository.dart';
import 'package:inkflow/features/profile/providers/profile_provider.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final List<String> _allStyles = [
    'Black Work',
    'Realismo',
    'Geométrico',
    'Aquarela',
    'Old School',
    'New School',
    'Minimalista',
    'Tribal',
    'Japonês',
    'Neo-Tradicional',
  ];
  final List<String> _selectedStyles = [];
  final List<Uint8List> _portfolioImages = [];
  final _minPriceController = TextEditingController(text: '150');
  final _hourlyRateController = TextEditingController(text: '200');
  final _bioController = TextEditingController();
  final _experienceController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _studioController = TextEditingController();
  final _instagramController = TextEditingController();
  final _picker = ImagePicker();
  final _locationsRepository = BrazilLocationsRepository();

  bool _isLoading = false;
  bool _isLoadingCities = false;
  bool _cityLookupFailed = false;
  List<String> _cities = const [];

  bool get _portfolioComplete => _portfolioImages.length >= 3;
  bool get _pricesComplete =>
      (double.tryParse(_minPriceController.text.replaceAll(',', '.')) ?? 0) >
          0 &&
      (double.tryParse(_hourlyRateController.text.replaceAll(',', '.')) ?? 0) >
          0;
  bool get _canActivate =>
      _portfolioComplete &&
      _selectedStyles.isNotEmpty &&
      _pricesComplete &&
      _professionalInfoComplete;
  bool get _professionalInfoComplete =>
      _bioController.text.trim().length >= 30 &&
      (int.tryParse(_experienceController.text) ?? 0) >= 1950 &&
      (int.tryParse(_experienceController.text) ?? 9999) <= DateTime.now().year &&
      _cityController.text.trim().isNotEmpty &&
      _stateController.text.trim().length == 2;
  int get _completedSteps =>
      (_selectedStyles.isNotEmpty ? 1 : 0) +
      (_pricesComplete ? 1 : 0) +
      (_professionalInfoComplete ? 1 : 0) +
      (_portfolioComplete ? 1 : 0);

  @override
  void dispose() {
    _minPriceController.dispose();
    _hourlyRateController.dispose();
    _bioController.dispose();
    _experienceController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _studioController.dispose();
    _instagramController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _portfolioImages.add(bytes));
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          userFriendlyErrorMessage(e),
        );
      }
    }
  }

  Future<void> _activateProfile() async {
    if (!_canActivate) return;

    setState(() => _isLoading = true);
    try {
      final repository = ref.read(profileRepositoryProvider);

      // Qualquer falha de upload aborta a ativação. Antes o erro era
      // engolido quando ao menos uma foto subia, e o perfil ficava público
      // com o portfólio incompleto sem ninguém ser avisado.
      final portfolioUrls = <String>[];
      for (var i = 0; i < _portfolioImages.length; i++) {
        portfolioUrls
            .add(await repository.uploadPortfolioImage(_portfolioImages[i], i));
      }

      await repository.activateArtistProfile(
        styles: _selectedStyles,
        minPrice:
            double.tryParse(_minPriceController.text.replaceAll(',', '.')) ??
                150,
        hourlyRate:
            double.tryParse(_hourlyRateController.text.replaceAll(',', '.')) ??
                200,
        portfolioUrls: portfolioUrls,
        bio: _bioController.text,
        careerStartYear: int.parse(_experienceController.text),
        city: _cityController.text,
        state: _stateController.text,
        studioName: _studioController.text,
        instagram: _instagramController.text,
      );

      ref.invalidate(userProfileProvider);

      if (!mounted) return;
      setState(() => _isLoading = false);
      await _showSuccessModal();
      if (mounted) context.go('/home');
    } on StorageException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showErrorSnackBar(
        context,
        'Falha ao enviar as fotos do portfólio (${e.message}). '
        'Verifique se o bucket "portfolio" existe no Supabase.',
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final hint = e.message.contains('Could not find')
          ? ' Execute os scripts em supabase/migrations no SQL Editor do Supabase.'
          : '';
      showErrorSnackBar(context, 'Erro ao ativar perfil: ${e.message}.$hint');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showErrorSnackBar(context, userFriendlyErrorMessage(e));
    }
  }

  Future<void> _showSuccessModal() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: InkFlowColors.accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle,
                  color: InkFlowColors.accent, size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              'Perfil Ativado!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Seu portfólio está no ar. Clientes já podem encontrá-lo na busca.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  void _toggleStyle(String style) {
    setState(() {
      if (_selectedStyles.contains(style)) {
        _selectedStyles.remove(style);
      } else {
        _selectedStyles.add(style);
      }
    });
  }

  Future<void> _chooseState() async {
    final selected = await showModalBottomSheet<BrazilianState>(
      context: context,
      backgroundColor: InkFlowColors.primarySoft,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: Column(
            children: [
              Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 18),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Selecione seu estado',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                  itemCount: BrazilLocationsRepository.states.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (context, index) {
                    final state = BrazilLocationsRepository.states[index];
                    return ListTile(
                      onTap: () => Navigator.pop(context, state),
                      title: Text(state.name,
                          style: const TextStyle(color: Colors.white)),
                      trailing: Text(
                        state.code,
                        style: const TextStyle(
                          color: InkFlowColors.accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;

    _stateController.text = selected.code;
    _cityController.clear();
    setState(() {
      _cities = const [];
      _cityLookupFailed = false;
      _isLoadingCities = true;
    });
    try {
      final cities = await _locationsRepository.fetchCities(selected.code);
      if (!mounted || _stateController.text != selected.code) return;
      setState(() => _cities = cities);
    } catch (_) {
      if (!mounted) return;
      setState(() => _cityLookupFailed = true);
    } finally {
      if (mounted && _stateController.text == selected.code) {
        setState(() => _isLoadingCities = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InkFlowColors.primary,
      appBar: AppBar(
        backgroundColor: InkFlowColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: const Text(
          'Perfil profissional',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    InkFlowColors.accent.withValues(alpha: 0.22),
                    Colors.white.withValues(alpha: 0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color: InkFlowColors.accent.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: InkFlowColors.accent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.workspace_premium_outlined,
                            color: InkFlowColors.primary),
                      ),
                      const SizedBox(width: 13),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Mostre seu trabalho',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800)),
                            SizedBox(height: 3),
                            Text('Complete as 4 etapas para aparecer na busca.',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                      Text('$_completedSteps/4',
                          style: const TextStyle(
                              color: InkFlowColors.accent,
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: _completedSteps / 4,
                      minHeight: 7,
                      color: InkFlowColors.accent,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _buildSectionCard(
              step: 1,
              complete: _selectedStyles.isNotEmpty,
              title: 'Seus estilos',
              subtitle: 'Selecione tudo o que representa o seu trabalho.',
              child: Wrap(
                spacing: 8,
                runSpacing: 10,
                children: _allStyles.map((style) {
                  final isSelected = _selectedStyles.contains(style);
                  return InkWell(
                    onTap: () => _toggleStyle(style),
                    borderRadius: BorderRadius.circular(99),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 9),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? InkFlowColors.accent
                            : InkFlowColors.primarySoft,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: isSelected
                              ? InkFlowColors.accent
                              : Colors.white.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected) ...[
                            const Icon(Icons.check_rounded,
                                size: 15, color: InkFlowColors.primary),
                            const SizedBox(width: 5),
                          ],
                          Text(
                            style,
                            style: TextStyle(
                              color: isSelected
                                  ? InkFlowColors.primary
                                  : Colors.white,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),
            _buildSectionCard(
              step: 2,
              complete: _pricesComplete,
              title: 'Preços de referência',
              subtitle: 'Você poderá combinar o valor final com cada cliente.',
              child: Row(
                children: [
                  Expanded(
                    child: _buildPriceField(
                      label: 'Valor mínimo',
                      controller: _minPriceController,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPriceField(
                      label: 'Valor por hora',
                      controller: _hourlyRateController,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _buildSectionCard(
              step: 3,
              complete: _professionalInfoComplete,
              title: 'Sobre você e atendimento',
              subtitle: 'Ajude clientes a conhecerem seu trabalho.',
              child: Column(
                children: [
                  _buildProfessionalField(
                    label: 'Biografia profissional *',
                    hint: 'Conte sobre sua trajetória, técnica e diferencial...',
                    controller: _bioController,
                    icon: Icons.notes_rounded,
                    maxLines: 4,
                    helper: '${_bioController.text.trim().length}/30 caracteres mínimos',
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(flex: 3, child: _buildCityField()),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: _buildStateField()),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildProfessionalField(
                          label: 'Ano em que começou *',
                          hint: 'Ex.: 2018',
                          controller: _experienceController,
                          icon: Icons.history_rounded,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildProfessionalField(
                          label: 'Nome do estúdio',
                          hint: 'Opcional',
                          controller: _studioController,
                          icon: Icons.storefront_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildProfessionalField(
                    label: 'Instagram profissional',
                    hint: '@seuusuario (opcional)',
                    controller: _instagramController,
                    icon: Icons.alternate_email_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _buildSectionCard(
              step: 4,
              complete: _portfolioComplete,
              title: 'Monte seu portfólio',
              subtitle:
                  '${_portfolioImages.length}/3 fotos obrigatórias • máximo de 6',
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ..._portfolioImages.asMap().entries.map(
                        (e) => _buildPhotoThumb(e.value, e.key),
                      ),
                  if (_portfolioImages.length < 6) _buildAddPhotoCard(),
                ],
              ),
            ),
            const SizedBox(height: 22),
            InkButton(
              label: _canActivate
                  ? 'Ativar perfil profissional'
                  : 'Complete as etapas para ativar',
              isLoading: _isLoading,
              onPressed: _canActivate ? _activateProfile : null,
            ),
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline_rounded,
                    size: 14, color: Colors.white38),
                SizedBox(width: 6),
                Text('Suas informações poderão ser editadas depois.',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required int step,
    required bool complete,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: complete
              ? InkFlowColors.accent.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: complete
                      ? InkFlowColors.accent
                      : Colors.white.withValues(alpha: 0.09),
                  shape: BoxShape.circle,
                ),
                child: complete
                    ? const Icon(Icons.check_rounded,
                        size: 18, color: InkFlowColors.primary)
                    : Text('$step',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11, height: 1.35)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildPriceField({
    required String label,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            prefixText: 'R\$ ',
            prefixStyle: const TextStyle(
                color: InkFlowColors.accent, fontWeight: FontWeight.w700),
            filled: true,
            fillColor: InkFlowColors.primary,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white12),
            ),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.white12)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: InkFlowColors.accent)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildProfessionalField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    int maxLines = 1,
    int? maxLength,
    String? helper,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          keyboardType: keyboardType,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
            prefixIcon: maxLines == 1
                ? Icon(icon, color: InkFlowColors.accent, size: 19)
                : null,
            filled: true,
            fillColor: InkFlowColors.primary,
            counterText: '',
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.white12)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: InkFlowColors.accent)),
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: 5),
          Align(
            alignment: Alignment.centerRight,
            child: Text(helper,
                style: TextStyle(
                    color: controller.text.trim().length >= 30
                        ? InkFlowColors.accent
                        : Colors.white38,
                    fontSize: 10)),
          ),
        ],
      ],
    );
  }

  Widget _buildStateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('UF *',
            style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 7),
        InkWell(
          onTap: _chooseState,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: InkFlowColors.primary,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _stateController.text.isEmpty
                        ? 'Escolher UF'
                        : _stateController.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _stateController.text.isEmpty
                          ? Colors.white30
                          : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Colors.white54, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCityField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Cidade *',
            style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 7),
        Autocomplete<String>(
          key: ValueKey(_stateController.text),
          initialValue: TextEditingValue(text: _cityController.text),
          optionsBuilder: (value) {
            final query = value.text.trim().toLowerCase();
            if (query.length < 2) return const Iterable<String>.empty();
            return _cities
                .where((city) => city.toLowerCase().contains(query))
                .take(8);
          },
          onSelected: (city) {
            _cityController.text = city;
            setState(() {});
          },
          fieldViewBuilder:
              (context, controller, focusNode, onFieldSubmitted) => TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: _stateController.text.isNotEmpty,
            onChanged: (value) {
              _cityController.text = value;
              setState(() {});
            },
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: _stateController.text.isEmpty
                  ? 'Escolha a UF'
                  : 'Digite a cidade',
              hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
              prefixIcon: const Icon(Icons.location_city_outlined,
                  color: InkFlowColors.accent, size: 19),
              suffixIcon: _isLoadingCities
                  ? const Padding(
                      padding: EdgeInsets.all(15),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              filled: true,
              fillColor: InkFlowColors.primary,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.white10)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.white12)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: InkFlowColors.accent)),
            ),
          ),
          optionsViewBuilder: (context, onSelected, options) => Align(
            alignment: Alignment.topLeft,
            child: Material(
              color: InkFlowColors.primarySoft,
              elevation: 12,
              borderRadius: BorderRadius.circular(14),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxHeight: 240, maxWidth: 230),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final city = options.elementAt(index);
                    return ListTile(
                      dense: true,
                      onTap: () => onSelected(city),
                      leading: const Icon(Icons.location_on_outlined,
                          color: InkFlowColors.accent, size: 18),
                      title: Text(city,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        if (_cityLookupFailed) ...[
          const SizedBox(height: 5),
          const Text('Sugestões indisponíveis; digite a cidade manualmente.',
              style: TextStyle(color: Colors.orangeAccent, fontSize: 9)),
        ],
      ],
    );
  }

  Widget _buildAddPhotoCard() {
    return GestureDetector(
      onTap: _pickPhoto,
      child: Container(
        width: 92,
        height: 108,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white30),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                color: Colors.white54, size: 28),
            SizedBox(height: 8),
            Text('Adicionar Foto',
                style: TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoThumb(Uint8List bytes, int index) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(bytes, width: 92, height: 108, fit: BoxFit.cover),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => setState(() => _portfolioImages.removeAt(index)),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFFEF4444),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }
}
