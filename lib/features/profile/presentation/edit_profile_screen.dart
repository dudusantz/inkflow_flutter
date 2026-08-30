import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inkflow/core/errors/error_utils.dart';
import 'package:inkflow/core/theme/app_theme.dart';
import 'package:inkflow/core/widgets/shared_widgets.dart';
import 'package:inkflow/features/profile/data/profile_repository.dart';
import 'package:inkflow/features/profile/domain/user_profile.dart';
import 'package:inkflow/features/profile/providers/profile_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _cpfController;
  late TextEditingController _birthDateController;
  late TextEditingController _guardianCpfController;

  bool _isSaving = false;
  bool _isInitialized = false;
  bool _isMinor = false;
  String _originalEmail = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _cpfController = TextEditingController();
    _birthDateController = TextEditingController();
    _guardianCpfController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cpfController.dispose();
    _birthDateController.dispose();
    _guardianCpfController.dispose();
    super.dispose();
  }

  void _initializeFields(UserProfile profile) {
    if (_isInitialized) return;

    _nameController.text = profile.name;
    _emailController.text = profile.email;
    _originalEmail = profile.email;

    _phoneController.text = profile.phone ?? '';
    _cpfController.text = profile.cpf ?? '';
    _birthDateController.text = profile.dateOfBirth ?? '';
    _guardianCpfController.text = profile.guardianCpf ?? '';

    if (_birthDateController.text.isNotEmpty) {
      try {
        final birthDate = DateTime.parse(_birthDateController.text);
        _checkAge(birthDate);
      } catch (_) {}
    }

    _isInitialized = true;
  }

  void _checkAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;

    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }

    setState(() {
      _isMinor = age < 18;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final newEmail = _emailController.text.trim();
    final emailChanged = newEmail != _originalEmail;

    try {
      final repository = ref.read(profileRepositoryProvider);

      if (emailChanged) {
        await repository.updateEmail(newEmail);
      }

      final birthDate = _birthDateController.text.trim();
      await repository.updatePersonalData(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        dateOfBirth: birthDate.isEmpty ? null : birthDate,
        guardianCpf: _isMinor ? _guardianCpfController.text.trim() : null,
      );

      ref.invalidate(userProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(emailChanged
                ? 'Perfil salvo! Verifique o novo e-mail para confirmá-lo.'
                : 'Dados atualizados com sucesso!'),
            backgroundColor: InkFlowColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, userFriendlyErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: InkFlowColors.background,
      appBar: AppBar(
        backgroundColor: InkFlowColors.primary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Editar Perfil',
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: profileAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: InkFlowColors.accent)),
        error: (e, s) => AsyncErrorView(
          error: e,
          customMessage: 'Erro ao carregar dados.',
          onRetry: () => ref.invalidate(userProfileProvider),
        ),
        data: (profile) {
          if (profile == null) {
            return const Center(
                child: CircularProgressIndicator(color: InkFlowColors.accent));
          }
          _initializeFields(profile);

          return SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAvatarSection(profile.avatarUrl),
                  const SizedBox(height: 40),

                  // Novo Padrão de Inputs: Limpo, Moderno, Sem Sombras Exageradas
                  _buildInputField(
                    label: 'Nome Completo',
                    controller: _nameController,
                    hintText: 'Como quer ser chamado',
                    prefixIcon: Icons.person_outline,
                    validator: (value) => value == null || value.isEmpty
                        ? 'Nome obrigatório'
                        : null,
                  ),
                  const SizedBox(height: 20),

                  _buildInputField(
                    label: 'E-mail',
                    controller: _emailController,
                    hintText: 'seu@email.com',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'E-mail obrigatório';
                      }
                      final emailRegex =
                          RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                      if (!emailRegex.hasMatch(value)) {
                        return 'Insira um formato de e-mail válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  _buildInputField(
                    label: 'Telefone',
                    controller: _phoneController,
                    hintText: 'Apenas números (com DDD)',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 20),

                  _buildInputField(
                    label: 'CPF',
                    controller: _cpfController,
                    hintText: '000.000.000-00',
                    prefixIcon: Icons.badge_outlined,
                    enabled: false, // Mantido bloqueado
                    suffixIcon: const Icon(Icons.lock_outline,
                        size: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),

                  _buildInputField(
                    label: 'Data de Nascimento',
                    controller: _birthDateController,
                    hintText: 'Selecione a data',
                    prefixIcon: Icons.calendar_today_outlined,
                    readOnly: true,
                    onTap: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime(2000),
                        firstDate: DateTime(1940),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: InkFlowColors.primary,
                                onPrimary: Colors.white,
                                onSurface: Colors.black,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (pickedDate != null) {
                        String formattedDate =
                            "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                        _birthDateController.text = formattedDate;
                        _checkAge(pickedDate);
                      }
                    },
                  ),

                  if (_isMinor) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.05),
                        border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _buildInputField(
                        label: 'CPF do Responsável Legal',
                        controller: _guardianCpfController,
                        hintText: 'Obrigatório para menores de 18',
                        prefixIcon: Icons.supervised_user_circle_outlined,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        validator: (value) {
                          if (_isMinor && (value == null || value.isEmpty)) {
                            return 'Forneça o CPF do responsável';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 48),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 2,
                        shadowColor:
                            const Color(0xFF10B981).withValues(alpha: 0.4),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 3))
                          : const Text(
                              'Salvar Alterações',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5),
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvatarSection(String? avatarUrl) {
    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 15,
                    spreadRadius: 2,
                    offset: const Offset(0, 5))
              ],
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: AvatarImage(url: avatarUrl, size: 108),
          ),
          // O botão nunca abriu seletor de imagem; enquanto a troca de avatar
          // não existir, ele avisa em vez de fingir que salvou.
          Semantics(
            button: true,
            label: 'Trocar foto de perfil (em desenvolvimento)',
            child: InkWell(
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Troca de foto em desenvolvimento.'),
                  behavior: SnackBarBehavior.floating,
                ),
              ),
              customBorder: const CircleBorder(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: InkFlowColors.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(Icons.camera_alt,
                    color: InkFlowColors.primary, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 👇 NOVO DESIGN SYSTEM PARA OS INPUTS
  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    String? hintText,
    IconData? prefixIcon,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    bool readOnly = false,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151)),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          readOnly: readOnly,
          onTap: onTap,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          style: TextStyle(
              color:
                  enabled ? const Color(0xFF1F2937) : const Color(0xFF9CA3AF),
              fontSize: 15),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: 20, color: const Color(0xFF6B7280))
                : null,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: enabled ? Colors.white : const Color(0xFFF3F4F6),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: InkFlowColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFF3F4F6)),
            ),
          ),
        ),
      ],
    );
  }
}
