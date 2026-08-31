import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:inkflow/core/errors/error_utils.dart';
import 'package:inkflow/core/theme/app_theme.dart';
import 'package:inkflow/core/widgets/shared_widgets.dart';
import 'package:inkflow/features/search/data/artist_directory_repository.dart';
import 'package:inkflow/features/search/domain/artist_summary.dart';

final publicArtistProvider = FutureProvider.autoDispose
    .family<ArtistSummary?, String>((ref, artistId) {
  return ref.watch(artistDirectoryRepositoryProvider).findById(artistId);
});

class ArtistProfileScreen extends ConsumerWidget {
  final String artistId;

  const ArtistProfileScreen({super.key, required this.artistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistAsync = ref.watch(publicArtistProvider(artistId));

    return artistAsync.when(
      loading: () => const Scaffold(
        backgroundColor: InkFlowColors.background,
        body: Center(
          child: CircularProgressIndicator(color: InkFlowColors.accent),
        ),
      ),
      error: (error, stack) => Scaffold(
        backgroundColor: InkFlowColors.background,
        body: SafeArea(
          child: AsyncErrorView(
            error: error,
            customMessage: 'Não foi possível carregar este perfil.',
            onRetry: () => ref.invalidate(publicArtistProvider(artistId)),
          ),
        ),
      ),
      data: (artist) => artist == null
          ? const Scaffold(
              backgroundColor: InkFlowColors.background,
              body: Center(child: Text('Perfil não encontrado.')),
            )
          : _ArtistProfileContent(artist: artist),
    );
  }
}

class _ArtistProfileContent extends StatelessWidget {
  final ArtistSummary artist;

  const _ArtistProfileContent({required this.artist});

  void _openPortfolioImage(BuildContext context, int initialIndex) {
    showDialog<void>(
      context: context,
      barrierColor: const Color(0xF20E0E12),
      builder: (dialogContext) => _PortfolioViewer(
        urls: artist.portfolioUrls,
        initialIndex: initialIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InkFlowColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: InkFlowColors.primary,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              tooltip: 'Voltar',
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go('/search'),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  NetworkImageWithFallback(
                    url: artist.coverImageUrl,
                    fallbackIcon: Icons.brush_outlined,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black12, Colors.black87],
                        stops: [0.45, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          artist.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                color: InkFlowColors.accent, size: 17),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                artist.city == null && artist.state == null
                                    ? 'Atendimento mediante agendamento'
                                    : artist.location,
                                style: const TextStyle(color: Colors.white70),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  children: [
                    _InfoPill(
                      icon: Icons.star_rounded,
                      label: artist.rating.toStringAsFixed(1),
                      color: InkFlowColors.warning,
                    ),
                    const SizedBox(width: 10),
                    const _InfoPill(
                      icon: Icons.verified_outlined,
                      label: 'Perfil profissional',
                      color: InkFlowColors.accentDark,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: InkFlowColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle('Especialidades'),
                      const SizedBox(height: 12),
                      if (artist.styles.isEmpty)
                        const Text(
                          'O profissional ainda não informou seus estilos.',
                          style: TextStyle(color: InkFlowColors.textMuted),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: artist.styles
                              .map((style) => Chip(
                                    label: Text(style),
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: InkFlowColors.accent
                                        .withValues(alpha: .1),
                                    side: BorderSide.none,
                                    labelStyle: const TextStyle(
                                      color: InkFlowColors.accentDark,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ))
                              .toList(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    const Expanded(child: _SectionTitle('Portfólio')),
                    if (artist.portfolioUrls.isNotEmpty)
                      Text(
                        '${artist.portfolioUrls.length} ${artist.portfolioUrls.length == 1 ? 'trabalho' : 'trabalhos'}',
                        style: const TextStyle(
                          color: InkFlowColors.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (artist.portfolioUrls.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: InkFlowColors.border),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.photo_library_outlined,
                            color: InkFlowColors.textMuted, size: 38),
                        SizedBox(height: 10),
                        Text(
                          'Nenhum trabalho publicado ainda.',
                          style: TextStyle(color: InkFlowColors.textMuted),
                        ),
                      ],
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: artist.portfolioUrls.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: .82,
                    ),
                    itemBuilder: (context, index) => Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _openPortfolioImage(context, index),
                        child: Hero(
                          tag: 'portfolio-${artist.id}-$index',
                          child: NetworkImageWithFallback(
                            url: artist.portfolioUrls[index],
                            fallbackIcon: Icons.image_not_supported_outlined,
                          ),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: InkFlowColors.background,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .08),
              blurRadius: 18,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          child: SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: () => context.push('/chat?contactId=${artist.id}'),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Conversar com o tatuador'),
              style: FilledButton.styleFrom(
                backgroundColor: InkFlowColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PortfolioViewer extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const _PortfolioViewer({required this.urls, required this.initialIndex});

  @override
  State<_PortfolioViewer> createState() => _PortfolioViewerState();
}

class _PortfolioViewerState extends State<_PortfolioViewer> {
  late final PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF0E0E12),
      child: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.urls.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) => InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: NetworkImageWithFallback(
                    url: widget.urls[index],
                    fallbackIcon: Icons.image_not_supported_outlined,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton.filledTonal(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                tooltip: 'Fechar',
              ),
            ),
            Positioned(
              top: 18,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Text(
                  '${_currentIndex + 1} de ${widget.urls.length}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: InkFlowColors.primary,
        fontSize: 19,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
