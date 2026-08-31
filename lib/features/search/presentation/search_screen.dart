import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:inkflow/core/errors/error_utils.dart';
import 'package:inkflow/core/theme/app_theme.dart';
import 'package:inkflow/core/widgets/shared_widgets.dart';
import 'package:inkflow/features/search/data/artist_directory_repository.dart';
import 'package:inkflow/features/search/domain/artist_summary.dart';

final artistsSearchProvider =
    FutureProvider.autoDispose<List<ArtistSummary>>((ref) {
  return ref.watch(artistDirectoryRepositoryProvider).listArtists();
});

const _allStyles = 'Todos';
const _allStates = 'Todos';
const _allCities = 'Todas';

/// Critérios de busca já confirmados pelo usuário.
class SearchFilters {
  final String query;
  final String style;
  final String state;
  final String city;

  const SearchFilters({
    this.query = '',
    this.style = _allStyles,
    this.state = _allStates,
    this.city = _allCities,
  });

  bool get isEmpty =>
      query.trim().isEmpty &&
      style == _allStyles &&
      state == _allStates &&
      city == _allCities;

  SearchFilters copyWith({
    String? query,
    String? style,
    String? state,
    String? city,
  }) {
    return SearchFilters(
      query: query ?? this.query,
      style: style ?? this.style,
      state: state ?? this.state,
      city: city ?? this.city,
    );
  }

  List<ArtistSummary> apply(List<ArtistSummary> artists) {
    final normalizedQuery = query.trim().toLowerCase();

    final matches = artists.where((artist) {
      final matchStyle = style == _allStyles || artist.styles.contains(style);
      final matchState = state == _allStates || artist.state == state;
      final matchCity = city == _allCities || artist.city == city;
      final matchQuery = normalizedQuery.isEmpty ||
          artist.name.toLowerCase().contains(normalizedQuery);
      return matchStyle && matchState && matchCity && matchQuery;
    }).toList();

    matches.sort((a, b) => b.rating.compareTo(a.rating));
    return matches;
  }

  String get locationLabel {
    if (state == _allStates) return 'Brasil (Todos os estados)';
    if (city == _allCities) return 'Todo o estado: $state';
    return '$city, $state';
  }
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _queryController = TextEditingController();

  /// Filtros em edição (o que o usuário está montando).
  SearchFilters _draft = const SearchFilters();

  /// Filtros efetivamente aplicados à lista.
  ///
  /// Antes existia apenas um conjunto: a filtragem acontecia a cada tecla e o
  /// botão "Buscar Tatuadores" só acendia uma mensagem de erro, sem efeito.
  SearchFilters? _applied;

  bool _showValidationError = false;

  final List<({String name, IconData icon})> _styleOptions = const [
    (name: _allStyles, icon: Icons.grid_view_rounded),
    (name: 'Black Work', icon: Icons.draw_outlined),
    (name: 'Realismo', icon: Icons.camera_alt_outlined),
    (name: 'Geométrico', icon: Icons.format_shapes_rounded),
    (name: 'Aquarela', icon: Icons.palette_outlined),
    (name: 'Old School', icon: Icons.anchor_rounded),
    (name: 'Minimalista', icon: Icons.horizontal_rule_rounded),
  ];

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _runSearch() {
    FocusScope.of(context).unfocus();

    if (_draft.isEmpty) {
      setState(() => _showValidationError = true);
      showErrorSnackBar(
        context,
        'Selecione ao menos um estilo, uma localização ou digite um nome.',
      );
      return;
    }

    setState(() {
      _showValidationError = false;
      _applied = _draft;
    });
  }

  List<String> _availableStates(List<ArtistSummary> artists) {
    final states = artists
        .map((a) => a.state)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
    return [_allStates, ...states];
  }

  List<String> _availableCities(List<ArtistSummary> artists, String state) {
    if (state == _allStates) return [_allCities];
    final cities = artists
        .where((a) => a.state == state)
        .map((a) => a.city)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
    return [_allCities, ...cities];
  }

  @override
  Widget build(BuildContext context) {
    final artistsAsync = ref.watch(artistsSearchProvider);

    return Scaffold(
      backgroundColor: InkFlowColors.background,
      body: SafeArea(
        bottom: false,
        child: artistsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                SkeletonLoader(height: 52, width: double.infinity),
                SizedBox(height: 16),
                SkeletonGrid(itemCount: 4),
              ],
            ),
          ),
          error: (err, stack) => AsyncErrorView(
            error: err,
            customMessage: 'Erro ao carregar tatuadores.',
            onRetry: () => ref.invalidate(artistsSearchProvider),
          ),
          data: (allArtists) {
            final filters = _applied;
            final results =
                filters == null ? allArtists : filters.apply(allArtists);

            return Column(
              children: [
                _buildHeader(allArtists),
                _buildStyleChips(),
                _buildSectionTitle(results.length),
                Expanded(child: _buildResultsGrid(results)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(List<ArtistSummary> allArtists) {
    return Container(
      decoration: const BoxDecoration(
        color: InkFlowColors.primary,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 20),
                tooltip: 'Voltar',
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                },
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Alterar região de busca',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openLocationModal(allArtists),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Buscando em',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                color: InkFlowColors.accent, size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _draft.locationLabel,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down,
                                color: Colors.white, size: 20),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: TextField(
              controller: _queryController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _runSearch(),
              onChanged: (value) => setState(() {
                _draft = _draft.copyWith(query: value);
                _showValidationError = false;
              }),
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Buscar tatuador pelo nome...',
                hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5), fontSize: 15),
                prefixIcon: Icon(Icons.search,
                    color: Colors.white.withValues(alpha: 0.7), size: 22),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _runSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: InkFlowColors.accent,
                foregroundColor: InkFlowColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Buscar Tatuadores',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (_showValidationError)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Selecione estilo, localização ou digite um nome.',
                style: TextStyle(color: Colors.red.shade300, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStyleChips() {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: _styleOptions.map((option) {
            final isSelected = _draft.style == option.name;

            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Semantics(
                selected: isSelected,
                button: true,
                child: GestureDetector(
                  onTap: () => setState(() {
                    _draft = _draft.copyWith(style: option.name);
                    _showValidationError = false;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? InkFlowColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color: isSelected
                              ? InkFlowColors.primary
                              : Colors.grey.shade300,
                          width: 1.5),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                  color: InkFlowColors.primary
                                      .withValues(alpha: 0.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4))
                            ]
                          : const [],
                    ),
                    child: Row(
                      children: [
                        Icon(option.icon,
                            size: 18,
                            color: isSelected
                                ? InkFlowColors.accent
                                : const Color(0xFF6B7280)),
                        const SizedBox(width: 8),
                        Text(
                          option.name,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF4B5563),
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(int count) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Inspirações para você',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: InkFlowColors.primary)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: InkFlowColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12)),
            child: Text('$count profissionais',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F766E))),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsGrid(List<ArtistSummary> results) {
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: Colors.grey.shade100, shape: BoxShape.circle),
              child: Icon(Icons.sentiment_dissatisfied_rounded,
                  size: 48, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 20),
            const Text('Nenhum profissional encontrado.',
                style: TextStyle(
                    color: Color(0xFF4B5563),
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Tente remover alguns filtros ou buscar em outro local.',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: results.length,
      itemBuilder: (context, index) => _ArtistCard(artist: results[index]),
    );
  }

  void _openLocationModal(List<ArtistSummary> allArtists) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        var pendingState = _draft.state;
        var pendingCity = _draft.city;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final states = _availableStates(allArtists);
            final cities = _availableCities(allArtists, pendingState);

            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Escolha sua região',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: InkFlowColors.primary)),
                      Container(
                        decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle),
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.black87),
                          tooltip: 'Fechar',
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('Estado',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: pendingState,
                    decoration: _modalFieldDecoration(),
                    items: states
                        .map((state) => DropdownMenuItem(
                            value: state,
                            child: Text(
                                state == _allStates ? 'Todo o Brasil' : state)))
                        .toList(),
                    onChanged: (value) => setModalState(() {
                      pendingState = value ?? _allStates;
                      pendingCity = _allCities;
                    }),
                  ),
                  const SizedBox(height: 24),
                  const Text('Cidade',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: pendingCity,
                    decoration: _modalFieldDecoration(
                        filled: pendingState == _allStates),
                    onChanged: pendingState == _allStates
                        ? null
                        : (value) => setModalState(
                            () => pendingCity = value ?? _allCities),
                    items: cities
                        .map((city) => DropdownMenuItem(
                            value: city,
                            child: Text(city == _allCities
                                ? 'Todas as cidades'
                                : city)))
                        .toList(),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _draft = _draft.copyWith(
                              state: pendingState, city: pendingCity);
                          _showValidationError = false;
                        });
                        Navigator.pop(sheetContext);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: InkFlowColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Confirmar Localização',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  SizedBox(
                      height: MediaQuery.of(context).padding.bottom > 0
                          ? MediaQuery.of(context).padding.bottom
                          : 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _modalFieldDecoration({bool filled = false}) {
    return InputDecoration(
      filled: filled,
      fillColor: Colors.grey.shade100,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: InkFlowColors.accent, width: 2)),
    );
  }
}

class _ArtistCard extends StatelessWidget {
  final ArtistSummary artist;

  const _ArtistCard({required this.artist});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/artist/${artist.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 15,
                offset: const Offset(0, 8))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                    child: NetworkImageWithFallback(
                      url: artist.coverImageUrl,
                      fallbackIcon: Icons.camera_alt_outlined,
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20)),
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7)
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 14, color: InkFlowColors.accent),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(artist.location,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
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
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          color: InkFlowColors.warning, size: 14),
                      const SizedBox(width: 4),
                      Text(artist.rating.toStringAsFixed(1),
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    artist.stylesLabel,
                    style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
