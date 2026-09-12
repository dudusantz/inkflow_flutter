import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:inkflow/core/errors/error_utils.dart';
import 'package:inkflow/core/theme/app_theme.dart';
import 'package:inkflow/core/widgets/shared_widgets.dart';
import 'package:inkflow/features/auth/providers/auth_provider.dart';
import 'package:inkflow/features/profile/domain/user_profile.dart';
import 'package:inkflow/features/profile/providers/profile_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(authRepositoryProvider).signOut();
      // O redirect do router leva para '/' assim que a sessão cai.
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, userFriendlyErrorMessage(e));
      }
    }
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Funcionalidade em desenvolvimento.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: InkFlowColors.background,
      appBar: AppBar(
        backgroundColor: InkFlowColors.primary,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Meu Perfil',
          style: TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
        ),
      ),
      body: profileAsync.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const Center(
          child: CircularProgressIndicator(color: InkFlowColors.accent),
        ),
        error: (err, stack) => AsyncErrorView(
          error: err,
          customMessage: 'Erro ao carregar perfil.',
          onRetry: () => ref.invalidate(userProfileProvider),
        ),
        data: (profile) {
          if (profile == null) {
            return const Center(
              child: CircularProgressIndicator(color: InkFlowColors.accent),
            );
          }
          return _buildProfileContent(context, ref, profile);
        },
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
    );
  }

  Widget _buildProfileContent(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, profile),
          const SizedBox(height: 18),
          if (profile.isArtist)
            _buildArtistDashboard(context)
          else
            _buildActivationCard(context),
          const SizedBox(height: 28),
          const _SectionLabel('Sua conta'),
          const SizedBox(height: 12),
          _buildListTile(Icons.person_outline, 'Dados pessoais',
              onTap: () => context.push('/edit-profile')),
          _buildListTile(Icons.lock_outline, 'Alterar Senha',
              onTap: () => context.push('/change-password')),
          _buildListTile(Icons.notifications_outlined, 'Notificações',
              onTap: () => context.push('/notifications')),
          _buildListTile(Icons.security_outlined, 'Privacidade e Segurança',
              onTap: () => context.push('/privacy')),
          const SizedBox(height: 32),
          const _SectionLabel('Suporte'),
          const SizedBox(height: 12),
          _buildListTile(Icons.help_outline, 'Central de Ajuda',
              onTap: () => _showComingSoon(context)),
          _buildListTile(Icons.description_outlined, 'Termos de Uso',
              onTap: () => _showComingSoon(context)),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton.icon(
              onPressed: () => _signOut(context, ref),
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              label: const Text('Sair da Conta',
                  style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                backgroundColor: Colors.red.withValues(alpha: 0.05),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, UserProfile profile) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE7E9ED)),
        boxShadow: [
          BoxShadow(
            color: InkFlowColors.primary.withValues(alpha: 0.07),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AvatarImage(url: profile.avatarUrl, size: 78),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: InkFlowColors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: const Icon(Icons.check,
                            color: Colors.white, size: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF172033),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: profile.isArtist
                              ? InkFlowColors.accent.withValues(alpha: 0.16)
                              : const Color(0xFFF0F2F5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          profile.isArtist
                              ? 'Perfil profissional'
                              : 'Conta de cliente',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: profile.isArtist
                                ? const Color(0xFF087F7A)
                                : const Color(0xFF667085),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        profile.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF788293)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEF0F3)),
          InkWell(
            onTap: () => context.push('/edit-profile'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: InkFlowColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_outlined,
                        color: Color(0xFF167D7B), size: 17),
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Text(
                      'Editar perfil',
                      style: TextStyle(
                        color: Color(0xFF263244),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Text(
                    'Atualizar dados',
                    style: TextStyle(fontSize: 11, color: Color(0xFF9299A5)),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFFA4ABB5), size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistDashboard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Painel do Estúdio', color: InkFlowColors.primary),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              // Cada item aponta para uma tela distinta. Antes "Portfólio",
              // "Tabela de Preços" e "Ativar perfil" levavam todos para a mesma
              // ProfileSetupScreen, e "Orçamentos" abria a inbox sem dizer.
              _buildDashboardAction(
                context,
                icon: Icons.calendar_month_outlined,
                title: 'Minha Agenda',
                subtitle: 'Gerencie suas sessões',
                route: '/schedule',
                isFirst: true,
              ),
              _buildDashboardAction(
                context,
                icon: Icons.image_outlined,
                title: 'Portfólio e Preços',
                subtitle: 'Fotos, estilos e valores',
                route: '/profile-setup',
              ),
              _buildDashboardAction(
                context,
                icon: Icons.bar_chart_outlined,
                title: 'Dashboard Financeiro',
                subtitle: 'Acompanhe seus resultados',
                route: '/dashboard',
              ),
              _buildDashboardAction(
                context,
                icon: Icons.chat_bubble_outline,
                title: 'Conversas com Clientes',
                subtitle: 'Responda a novos clientes',
                route: '/inbox',
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivationCard(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/profile-setup'),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF111218), Color(0xFF26333B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF1F2937).withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle),
              child:
                  const Icon(Icons.brush_rounded, color: InkFlowColors.accent),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Transforme arte em oportunidades',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text(
                      'Crie seu perfil de tatuador, publique seu portfólio e receba novos clientes.',
                      style: TextStyle(
                          color: Color(0xFFC5CBD3),
                          fontSize: 12,
                          height: 1.35)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded,
                color: InkFlowColors.accent, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardAction(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle,
      required String route,
      bool isFirst = false,
      bool isLast = false}) {
    return InkWell(
      onTap: () => context.push(route),
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(16) : Radius.zero,
        bottom: isLast ? const Radius.circular(16) : Radius.zero,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(
                  bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: InkFlowColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: InkFlowColors.primary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF1F2937))),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile(IconData icon, String title,
      {required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          minTileHeight: 60,
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: InkFlowColors.accent.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: const Color(0xFF1E6F70), size: 20),
          ),
          title: Text(title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1F2937))),
          trailing: const Icon(Icons.chevron_right,
              color: Color(0xFF9CA3AF), size: 20),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;

  const _SectionLabel(this.text, {this.color = const Color(0xFF9CA3AF)});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color),
    );
  }
}
