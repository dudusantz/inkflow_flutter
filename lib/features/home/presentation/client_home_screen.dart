import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:inkflow/core/theme/app_theme.dart';
import 'package:inkflow/core/widgets/shared_widgets.dart';
import 'package:inkflow/features/schedule/data/appointment_repository.dart';
import 'package:inkflow/features/schedule/domain/appointment.dart';
import 'package:inkflow/features/search/data/artist_directory_repository.dart';
import 'package:inkflow/features/search/domain/artist_summary.dart';
import 'package:inkflow/features/profile/providers/profile_provider.dart';

final trendingArtistsProvider =
    FutureProvider.autoDispose<List<ArtistSummary>>((ref) {
  return ref.watch(artistDirectoryRepositoryProvider).trending();
});

final nextSessionProvider = FutureProvider.autoDispose<Appointment?>((ref) {
  return ref.watch(appointmentRepositoryProvider).nextSessionForClient();
});

class ClientHomeScreen extends ConsumerStatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  ConsumerState<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends ConsumerState<ClientHomeScreen> {
  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Funcionalidade em desenvolvimento'),
        backgroundColor: InkFlowColors.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;

    return Scaffold(
      backgroundColor: InkFlowColors.background,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildHeader(profile?.firstName ?? 'Cliente', profile?.avatarUrl),
            _buildQuickActions(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: ResponsiveBody(
                  maxWidth: 920,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSearchBar(),
                      const SizedBox(height: 40),
                      _buildSectionTitle('Minha Próxima Sessão', 'Ver detalhes',
                          () => context.go('/schedule')),
                      const SizedBox(height: 16),
                      _buildNextSessionSection(),
                      const SizedBox(height: 40),
                      _buildSectionTitle('Estúdios em Alta', 'Explorar',
                          () => context.go('/search')),
                      const SizedBox(height: 16),
                      _buildRecommendedArtists(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }

  Widget _buildHeader(String firstName, String? avatarUrl) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 20, 20, 24),
      decoration: const BoxDecoration(
        gradient: InkFlowColors.heroGradient,
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const InkFlowLogo(height: 32),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined,
                        color: Colors.white),
                    tooltip: 'Notificações',
                    onPressed: _showComingSoon,
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => context.go('/profile'),
                    customBorder: const CircleBorder(),
                    child:
                        AvatarImage(url: avatarUrl, size: 40, borderWidth: 2),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Olá, $firstName',
              style: const TextStyle(
                  color: Color(0x99FFFFFF),
                  fontSize: 15,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          const Text('Sua próxima arte começa aqui.',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5)),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      decoration: const BoxDecoration(
        color: InkFlowColors.white,
        border: Border(bottom: BorderSide(color: InkFlowColors.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _actionButton(
              Icons.explore_outlined, 'Explorar', () => context.go('/search')),
          _actionButton(Icons.favorite_border, 'Favoritos',
              () => context.push('/favorites')),
          _actionButton(Icons.medical_information_outlined, 'Cuidados',
              () => context.push('/care')),
          _actionButton(Icons.chat_bubble_outline, 'Mensagens',
              () => context.go('/inbox')),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: InkFlowColors.accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: InkFlowColors.accentDark, size: 25),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4B5563))),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return InkSurface(
      onTap: () => context.go('/search'),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      child: Row(
        children: [
          const Icon(Icons.search_rounded,
              color: InkFlowColors.accentDark, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Buscar estúdios, artistas ou estilos...',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, String action, VoidCallback onTap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: InkFlowColors.primary)),
        GestureDetector(
            onTap: onTap,
            child: Text(action,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: InkFlowColors.accentDark))),
      ],
    );
  }

  Widget _buildNextSessionSection() {
    final sessionAsync = ref.watch(nextSessionProvider);

    return sessionAsync.when(
      data: (session) =>
          session == null ? _buildEmptySessionCard() : _sessionCard(session),
      loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
              child: CircularProgressIndicator(color: InkFlowColors.accent))),
      error: (e, s) => _buildEmptySessionCard(),
    );
  }

  Widget _sessionCard(Appointment session) {
    final month = DateFormat('MMM', 'pt_BR').format(session.date).toUpperCase();
    final day = DateFormat('dd').format(session.date);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
                color: InkFlowColors.primary,
                borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                Text(month,
                    style: const TextStyle(
                        color: InkFlowColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
                Text(day,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sessão - ${session.style}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: InkFlowColors.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time_filled,
                        size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        session.timeRangeLabel,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                  color: InkFlowColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(
                session.status.toUpperCase(),
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF059669),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySessionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          Icon(Icons.event_busy, color: Colors.grey.shade300, size: 40),
          const SizedBox(height: 12),
          const Text('Nenhuma sessão agendada',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: InkFlowColors.primary)),
          const SizedBox(height: 8),
          Text('Sua pele está em branco. Que tal encontrar uma inspiração?',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.go('/search'),
            style: ElevatedButton.styleFrom(
                backgroundColor: InkFlowColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: const Text('Explorar Estúdios',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedArtists() {
    final artistsAsync = ref.watch(trendingArtistsProvider);

    return artistsAsync.when(
      data: (artists) {
        if (artists.isEmpty) {
          return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('Nenhum estúdio cadastrado ainda.',
                  style: TextStyle(color: Colors.grey, fontSize: 14)));
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: artists.map(_artistCard).toList(),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: InkFlowColors.accent,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Buscando estúdios…',
              style: TextStyle(color: InkFlowColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      ),
      error: (error, stack) => _buildArtistsError(),
    );
  }

  Widget _buildArtistsError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: InkFlowColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined,
              color: InkFlowColors.textMuted, size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Não foi possível carregar os estúdios agora.',
              style: TextStyle(color: InkFlowColors.textMuted, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () => ref.invalidate(trendingArtistsProvider),
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _artistCard(ArtistSummary artist) {
    final imageUrl = artist.coverImageUrl;

    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: NetworkImageWithFallback(
              url: imageUrl,
              height: 110,
              width: double.infinity,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(artist.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: InkFlowColors.primary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(artist.stylesLabel,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star,
                        color: InkFlowColors.warning, size: 16),
                    const SizedBox(width: 4),
                    Text(artist.rating.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
