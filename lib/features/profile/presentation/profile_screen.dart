import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inkflow/core/theme/app_theme.dart';
import 'package:inkflow/features/auth/providers/auth_provider.dart';

// Busca os dados reais do perfil (Nome, Foto, Role) no Supabase
final userProfileProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  if (user == null) return null;

  return await supabase
      .from('profiles')
      .select()
      .eq('id', user.id)
      .maybeSingle();
});

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isLoadingAvatar = false;

  // --- LÓGICA DE UPLOAD DA FOTO DE PERFIL ---
  Future<void> _updateAvatar() async {
    final picker = ImagePicker();
    final file =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;

    setState(() => _isLoadingAvatar = true);

    try {
      final bytes = await file.readAsBytes();
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;

      // Cria um nome de arquivo único para não ter erro de cache
      final path =
          '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Faz o upload para o bucket 'avatars'
      await supabase.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions:
                const FileOptions(upsert: true, contentType: 'image/jpeg'),
          );

      // Pega o link público da imagem gerada
      final publicUrl = supabase.storage.from('avatars').getPublicUrl(path);

      // Atualiza a tabela profiles com o novo link
      await supabase
          .from('profiles')
          .update({'avatar_url': publicUrl}).eq('id', userId);

      // Força a tela a recarregar os dados para mostrar a foto nova
      ref.invalidate(userProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Foto atualizada com sucesso!'),
              backgroundColor: Color(0xFF10B981)),
        );
      }
    } catch (e) {
      debugPrint('Erro ao fazer upload da foto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Erro ao atualizar foto. Verifique se o bucket "avatars" existe.'),
              backgroundColor: Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingAvatar = false);
    }
  }

  // --- LÓGICA REAL DE RECUPERAÇÃO DE SENHA ---
  Future<void> _resetPassword(String? email) async {
    if (email == null) return;
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Enviámos um link de redefinição para o seu e-mail.'),
              backgroundColor: Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Erro ao enviar e-mail de recuperação.'),
              backgroundColor: Color(0xFFEF4444)),
        );
      }
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature em desenvolvimento 🚀'),
        backgroundColor: InkFlowColors.accent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F5),
      appBar: AppBar(
        backgroundColor: InkFlowColors.primary,
        elevation: 0,
        centerTitle: true,
        // 👇 BOTÃO DE VOLTAR ADICIONADO AQUI
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: const Text('Meu Perfil',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
      ),
      body: profileAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: InkFlowColors.accent)),
        error: (e, s) => Center(child: Text('Erro ao carregar perfil: $e')),
        data: (profileData) {
          final name = profileData?['name'] ?? 'Usuário';
          final avatarUrl = profileData?['avatar_url'];
          final isArtist = profileData?['role'] == 'ARTIST';

          return SingleChildScrollView(
            child: Column(
              children: [
                _buildProfileHeader(user?.email ?? '', name, avatarUrl),
                const SizedBox(height: 24),
                if (!isArtist) _buildUpgradeBanner(context),
                const SizedBox(height: 24),
                _buildSettingsList(context, user?.email),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(String email, String name, String? avatarUrl) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 32, top: 24),
      decoration: const BoxDecoration(
        color: InkFlowColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: InkFlowColors.accent, width: 3)),
                child: CircleAvatar(
                  radius: 45,
                  backgroundColor: Colors.grey.shade800,
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null
                      ? const Icon(Icons.person,
                          size: 40, color: Colors.white54)
                      : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _isLoadingAvatar ? null : _updateAvatar,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                        color: InkFlowColors.accent, shape: BoxShape.circle),
                    child: _isLoadingAvatar
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: InkFlowColors.primary, strokeWidth: 2))
                        : const Icon(Icons.camera_alt,
                            color: InkFlowColors.primary, size: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(email,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.7), fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildUpgradeBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => context.push('/profile-setup'),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF1F2937), Colors.black],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 8))
            ],
            border: Border.all(color: InkFlowColors.accent.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: InkFlowColors.accent.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.draw,
                    color: InkFlowColors.accent, size: 28),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Você é Tatuador?',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text(
                        'Ative seu perfil profissional, adicione seu portfólio e receba clientes.',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  color: InkFlowColors.accent, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsList(BuildContext context, String? email) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Configurações da Conta',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey)),
          const SizedBox(height: 12),
          _buildListTile(Icons.person_outline, 'Editar Dados Pessoais',
              onTap: () => _showComingSoon('Edição de dados')),
          _buildListTile(Icons.lock_outline, 'Alterar Senha',
              onTap: () => _resetPassword(email)),
          _buildListTile(Icons.notifications_outlined, 'Notificações',
              onTap: () => _showComingSoon('Central de Notificações')),
          _buildListTile(Icons.privacy_tip_outlined, 'Privacidade e Segurança',
              onTap: () => _showComingSoon('Privacidade')),
          const SizedBox(height: 24),
          const Text('Suporte',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey)),
          const SizedBox(height: 12),
          _buildListTile(Icons.help_outline, 'Central de Ajuda',
              onTap: () => _showComingSoon('FAQ')),
          _buildListTile(Icons.description_outlined, 'Termos de Uso',
              onTap: () => _showComingSoon('Termos Legais')),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                ref.read(authRepositoryProvider).signOut();
              },
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              label: const Text('Sair da Conta',
                  style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.1),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildListTile(IconData icon, String title,
      {required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: InkFlowColors.primary, size: 20)),
          title: Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Color(0xFF1F2937))),
          trailing:
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onTap: onTap,
        ),
      ),
    );
  }
}
