import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  final _picker = ImagePicker();

  bool _isLoading = false;

  bool get _portfolioComplete => _portfolioImages.length >= 3;

  @override
  void dispose() {
    _minPriceController.dispose();
    _hourlyRateController.dispose();
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
    if (!_portfolioComplete || _selectedStyles.isEmpty) return;

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
        minPrice: double.tryParse(_minPriceController.text) ?? 150,
        hourlyRate: double.tryParse(_hourlyRateController.text) ?? 200,
        portfolioUrls: portfolioUrls,
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
          'Ativar Perfil Profissional',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              'Estilos de Tatuagem',
              'Quais estilos você domina?',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 12,
              children: _allStyles.map((style) {
                final isSelected = _selectedStyles.contains(style);
                return GestureDetector(
                  onTap: () => _toggleStyle(style),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isSelected ? InkFlowColors.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? InkFlowColors.accent
                            : Colors.white30,
                      ),
                    ),
                    child: Text(
                      style,
                      style: TextStyle(
                        color: isSelected ? InkFlowColors.primary : Colors.white,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 40),
            _buildSectionHeader(
              'Tabela de Preços Base',
              'Valor mínimo e valor por hora para orçamentos rápidos.',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildPriceField(
                    label: 'Valor Mínimo (R\$)',
                    controller: _minPriceController,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPriceField(
                    label: 'Valor Hora (R\$)',
                    controller: _hourlyRateController,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            _buildSectionHeader(
              'Portfólio',
              'Adicione pelo menos 3 fotos (${_portfolioImages.length}/3)',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ..._portfolioImages.asMap().entries.map(
                      (e) => _buildPhotoThumb(e.value, e.key),
                    ),
                if (_portfolioImages.length < 6) _buildAddPhotoCard(),
              ],
            ),
            const SizedBox(height: 48),
            InkButton(
              label: 'Ativar Perfil',
              isLoading: _isLoading,
              onPressed: (_portfolioComplete && _selectedStyles.isNotEmpty)
                  ? _activateProfile
                  : null,
            ),
            if (!_portfolioComplete) ...[
              const SizedBox(height: 12),
              Text(
                'É necessário enviar pelo menos 3 imagens para ativar seu portfólio.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style:
              TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
        ),
      ],
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
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.08),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildAddPhotoCard() {
    return GestureDetector(
      onTap: _pickPhoto,
      child: Container(
        width: 100,
        height: 120,
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
          child: Image.memory(bytes, width: 100, height: 120, fit: BoxFit.cover),
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
