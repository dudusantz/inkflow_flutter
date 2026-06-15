import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

const _allStyles = [
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

const _prices = [
  {'size': 'Micro (até 3cm)', 'price': 'R\$ 150'},
  {'size': 'Pequeno (3–8cm)', 'price': 'R\$ 300'},
  {'size': 'Médio (8–15cm)', 'price': 'R\$ 600'},
  {'size': 'Grande (15–25cm)', 'price': 'R\$ 1.200'},
  {'size': 'Extra Grande (25cm+)', 'price': 'R\$ 2.500'},
];

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final List<String> _selectedStyles = [];
  final List<XFile> _uploadedPhotos = []; // Dados reais do image_picker
  final ImagePicker _picker = ImagePicker();

  bool _submitted = false;
  bool _isLoading = false;

  bool get _canActivate =>
      _uploadedPhotos.length >= 3 && _selectedStyles.isNotEmpty;

  void _toggleStyle(String style) {
    setState(() {
      if (_selectedStyles.contains(style)) {
        _selectedStyles.remove(style);
      } else {
        _selectedStyles.add(style);
      }
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // Compressão básica para otimizar upload
      );

      if (image != null) {
        setState(() {
          _uploadedPhotos.add(image);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao abrir a galeria. Verifique as permissões.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _handleActivate() async {
    if (!_canActivate) return;

    setState(() => _isLoading = true);

    try {
      // TODO: Implementar lógica de Storage real no Backend
      // 1. Fazer upload de _uploadedPhotos para o bucket do Supabase
      // 2. Salvar as URLs públicas e _selectedStyles na tabela do perfil

      await Future.delayed(const Duration(milliseconds: 2000)); // Simula o upload

      if (mounted) {
        setState(() {
          _isLoading = false;
          _submitted = true;
        });
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) context.go('/home');
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InkFlowColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
                title: 'Configurar Perfil',
                showBack: true,
                backTo: '/home',
                dark: true),
            if (_submitted)
              Expanded(child: _buildSuccess())
            else
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('Estilos de Tatuagem'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _allStyles.map((style) {
                          final sel = _selectedStyles.contains(style);
                          return GestureDetector(
                            onTap: () => _toggleStyle(style),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: sel
                                    ? InkFlowColors.accent
                                    : Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: sel
                                      ? InkFlowColors.accent
                                      : Colors.white.withOpacity(0.2),
                                ),
                              ),
                              child: Text(
                                style,
                                style: TextStyle(
                                  color: sel
                                      ? InkFlowColors.primary
                                      : Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      _sectionTitle('Tabela de Preços Base'),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Column(
                          children: _prices.asMap().entries.map((entry) {
                            final i = entry.key;
                            final p = entry.value;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                border: i < _prices.length - 1
                                    ? Border(
                                        bottom: BorderSide(
                                            color:
                                                Colors.white.withOpacity(0.05)))
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    p['size']!,
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 12),
                                  ),
                                  const Spacer(),
                                  Text(
                                    p['price']!,
                                    style: const TextStyle(
                                        color: InkFlowColors.accent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          _sectionTitle('Portfólio'),
                          const Spacer(),
                          Text(
                            '${_uploadedPhotos.length}/3 mínimo',
                            style: TextStyle(
                              color: _uploadedPhotos.length >= 3
                                  ? InkFlowColors.accent
                                  : const Color(0xFFEF4444),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (!_canActivate && _uploadedPhotos.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                    const Color(0xFFEF4444).withOpacity(0.3)),
                          ),
                          child: const Text(
                            'Ainda faltam imagens para atingir o mínimo exigido.',
                            style: TextStyle(
                                color: Color(0xFFEF4444), fontSize: 11),
                          ),
                        ),
                      GridView.count(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          // AQUI ESTÁ A CORREÇÃO: Forçamos a tipagem "XFile file" no map 
                          // e adicionamos o operador "!" no ".path"
                          ..._uploadedPhotos.map((XFile file) => Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.file(
                                      File(file.path), 
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () => setState(
                                          () => _uploadedPhotos.remove(file)),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close,
                                            color: Colors.white, size: 14),
                                      ),
                                    ),
                                  )
                                ],
                              )),
                          // Botão de adicionar real
                          GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    style: BorderStyle.solid),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate,
                                      color: Colors.white.withOpacity(0.4),
                                      size: 24),
                                  const SizedBox(height: 4),
                                  Text('Adicionar',
                                      style: TextStyle(
                                          color: Colors.white.withOpacity(0.4),
                                          fontSize: 10)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      InkButton(
                        label: _canActivate
                            ? 'Ativar Perfil Profissional'
                            : 'Portfólio Incompleto',
                        onPressed: _canActivate && !_isLoading
                            ? _handleActivate
                            : null,
                        isLoading: _isLoading,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: InkFlowColors.accent.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check,
                  color: InkFlowColors.accent, size: 40),
            ),
            const SizedBox(height: 20),
            const Text('Perfil Ativado!',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text.rich(
              TextSpan(
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5), fontSize: 14),
                children: [
                  const TextSpan(text: 'Seu status foi alterado para '),
                  const TextSpan(
                      text: 'Tatuador',
                      style: TextStyle(color: InkFlowColors.accent)),
                  const TextSpan(text: ' e você já aparece nas buscas.'),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}