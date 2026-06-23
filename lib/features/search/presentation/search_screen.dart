import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inkflow/core/theme/app_theme.dart';
import 'package:inkflow/core/widgets/shared_widgets.dart';

// --- PROVIDER DE DADOS REAIS (SUPABASE) ---
// Ele vai buscar apenas quem tem a role 'ARTIST' na tabela 'profiles'
final artistsSearchProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final response = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('role', 'ARTIST');
    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    debugPrint('Erro ao buscar tatuadores: $e');
    return [];
  }
});

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  String _searchQuery = '';
  String _selectedStyle = 'Todos';
  String _selectedState = 'Todos';
  String _selectedCity = 'Todas';
  bool _showValidationError = false;

  bool get _hasActiveFilter =>
      _searchQuery.isNotEmpty ||
      _selectedStyle != 'Todos' ||
      _selectedState != 'Todos' ||
      _selectedCity != 'Todas';

  void _runSearch() {
    if (!_hasActiveFilter) {
      setState(() => _showValidationError = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Por favor, selecione ao menos um estilo ou localização para buscar.',
          ),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }
    setState(() => _showValidationError = false);
  }

  // Filtros Visuais Premium (Ícones Nativos)
  final List<Map<String, dynamic>> _styles = [
    {'name': 'Todos', 'icon': Icons.grid_view_rounded},
    {'name': 'Black Work', 'icon': Icons.draw_outlined},
    {'name': 'Realismo', 'icon': Icons.camera_alt_outlined},
    {'name': 'Geométrico', 'icon': Icons.format_shapes_rounded},
    {'name': 'Aquarela', 'icon': Icons.palette_outlined},
    {'name': 'Old School', 'icon': Icons.anchor_rounded},
    {'name': 'Minimalista', 'icon': Icons.horizontal_rule_rounded},
  ];

  // Filtra a lista real vinda do banco
  List<Map<String, dynamic>> _filterArtists(
      List<Map<String, dynamic>> allArtists) {
    final filtered = allArtists.where((artist) {
      // Tratamento seguro para dados que podem estar nulos no banco
      final artistStyles =
          (artist['styles'] as List?)?.map((e) => e.toString()).toList() ?? [];
      final artistState = artist['state']?.toString() ?? '';
      final artistCity = artist['city']?.toString() ?? '';
      final artistName = artist['name']?.toString() ?? '';

      final matchStyle =
          _selectedStyle == 'Todos' || artistStyles.contains(_selectedStyle);
      final matchState =
          _selectedState == 'Todos' || artistState == _selectedState;
      final matchCity = _selectedCity == 'Todas' || artistCity == _selectedCity;
      final matchSearch = _searchQuery.isEmpty ||
          artistName.toLowerCase().contains(_searchQuery.toLowerCase());

      return matchStyle && matchState && matchCity && matchSearch;
    }).toList();

    filtered.sort((a, b) {
      final ratingA =
          double.tryParse(a['rating']?.toString() ?? '0') ?? 0;
      final ratingB =
          double.tryParse(b['rating']?.toString() ?? '0') ?? 0;
      return ratingB.compareTo(ratingA);
    });
    return filtered;
  }

  // Define os estados e cidades disponíveis baseados APENAS nos artistas que existem
  List<String> _getAvailableStates(List<Map<String, dynamic>> allArtists) {
    final states = allArtists
        .map((a) => a['state']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    states.sort();
    return ['Todos', ...states];
  }

  List<String> _getAvailableCities(List<Map<String, dynamic>> allArtists) {
    if (_selectedState == 'Todos') return ['Todas'];
    final cities = allArtists
        .where((a) => a['state'] == _selectedState)
        .map((a) => a['city']?.toString() ?? '')
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    cities.sort();
    return ['Todas', ...cities];
  }

  String get _currentLocationText {
    if (_selectedState == 'Todos') return 'Brasil (Todos os estados)';
    if (_selectedCity == 'Todas') return 'Todo o estado: $_selectedState';
    return '$_selectedCity, $_selectedState';
  }

  @override
  Widget build(BuildContext context) {
    // Escuta o provider do banco de dados
    final artistsAsync = ref.watch(artistsSearchProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        bottom: false,
        child: artistsAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const SkeletonLoader(height: 52, width: double.infinity),
                const SizedBox(height: 16),
                const SkeletonGrid(itemCount: 4),
              ],
            ),
          ),
          error: (err, stack) => Center(child: Text('Erro ao carregar: $err')),
          data: (allArtists) {
            final results = _filterArtists(allArtists);
            final availableStates = _getAvailableStates(allArtists);

            return Column(
              children: [
                _buildHeader(availableStates, allArtists),
                _buildVisualFilterChips(),
                _buildSectionTitle('Inspirações para você', results.length),
                Expanded(child: _buildResultsGrid(results)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(
      List<String> availableStates, List<Map<String, dynamic>> allArtists) {
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
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                },
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque, // Melhora a área de clique
                  onTap: () => _openLocationModal(availableStates, allArtists),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Buscando em',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
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
                              _currentLocationText,
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
            ],
          ),
          const SizedBox(height: 24),
          Container(
            height: 52, // Altura maior para facilitar o toque
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: TextField(
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Buscar tatuador pelo nome...',
                hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.5), fontSize: 15),
                prefixIcon: Icon(Icons.search,
                    color: Colors.white.withOpacity(0.7), size: 22),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _showValidationError = false;
                });
              },
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
                style: TextStyle(
                  color: Colors.red.shade300,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVisualFilterChips() {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: _styles.map((styleObj) {
            final styleName = styleObj['name'] as String;
            final styleIcon = styleObj['icon'] as IconData;
            final isSelected = _selectedStyle == styleName;

            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () => setState(() => _selectedStyle = styleName),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? InkFlowColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(30), // Mais arredondado
                    border: Border.all(
                        color: isSelected
                            ? InkFlowColors.primary
                            : Colors.grey.shade300,
                        width: 1.5),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                                color: InkFlowColors.primary.withOpacity(0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 4))
                          ]
                        : [],
                  ),
                  child: Row(
                    children: [
                      Icon(styleIcon,
                          size: 18,
                          color: isSelected
                              ? InkFlowColors.accent
                              : const Color(0xFF6B7280)),
                      const SizedBox(width: 8),
                      Text(
                        styleName,
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
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, int count) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: InkFlowColors.primary)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: InkFlowColors.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12)),
            child: Text('$count profissionais',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: InkFlowColors.accent)),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsGrid(List<Map<String, dynamic>> results) {
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
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65, // Ajustado para não cortar fotos verticalmente
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: results.length,
      itemBuilder: (context, index) => _buildArtistCard(results[index]),
    );
  }

  Widget _buildArtistCard(Map<String, dynamic> artist) {
    // Validações seguras para evitar quebras se o banco estiver faltando dados
    final String name = artist['name']?.toString() ?? 'Tatuador';
    final String city = artist['city']?.toString() ?? '';
    final String state = artist['state']?.toString() ?? '';
    final String location = city.isNotEmpty && state.isNotEmpty
        ? '$city, $state'
        : 'Local não informado';
    final String imageUrl = artist['portfolio_url']?.toString() ??
        ((artist['portfolio_urls'] as List?)?.isNotEmpty == true
            ? artist['portfolio_urls'][0].toString()
            : null) ??
        artist['avatar_url']?.toString() ??
        '';
    final List<String> styles =
        (artist['styles'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final rating = artist['rating']?.toString() ?? '5.0';

    return GestureDetector(
      onTap: () => context.go('/chat?artistId=${artist['id']}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
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
                    child: imageUrl.isNotEmpty
                        ? Image.network(imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _fallbackImage())
                        : _fallbackImage(),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20)),
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7)
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
                          child: Text(location,
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
                  Text(name,
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
                          color: Color(0xFFF59E0B), size: 14),
                      const SizedBox(width: 4),
                      Text(rating,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    styles.isNotEmpty
                        ? styles.join(' • ')
                        : 'Estilo não definido',
                    style: TextStyle(
                        color: Colors.grey.shade500,
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

  Widget _fallbackImage() {
    return Container(
        color: Colors.grey.shade200,
        child: const Icon(Icons.camera_alt_outlined,
            color: Colors.grey, size: 40));
  }

  // --- MODAL DE LOCALIZAÇÃO OTIMIZADO ---
  void _openLocationModal(
      List<String> availableStates, List<Map<String, dynamic>> allArtists) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            List<String> modalCities = ['Todas'];
            if (_selectedState != 'Todos') {
              final cities = allArtists
                  .where((a) => a['state'] == _selectedState)
                  .map((a) => a['city']?.toString() ?? '')
                  .where((c) => c.isNotEmpty)
                  .toSet()
                  .toList();
              cities.sort();
              modalCities.addAll(cities);
            }

            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(32)), // Mais arredondado
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
                            icon:
                                const Icon(Icons.close, color: Colors.black87),
                            onPressed: () => context.pop()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('Estado',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedState,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16), // Mais alto
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: InkFlowColors.accent, width: 2)),
                    ),
                    items: availableStates
                        .map((state) => DropdownMenuItem(
                            value: state,
                            child: Text(
                                state == 'Todos' ? 'Todo o Brasil' : state)))
                        .toList(),
                    onChanged: (value) {
                      setModalState(() {
                        _selectedState = value!;
                        _selectedCity = 'Todas';
                      });
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text('Cidade',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedCity,
                    onChanged: _selectedState == 'Todos'
                        ? null
                        : (value) {
                            setModalState(() => _selectedCity = value!);
                            setState(() {});
                          },
                    decoration: InputDecoration(
                      filled: _selectedState == 'Todos',
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16), // Mais alto
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: InkFlowColors.accent, width: 2)),
                    ),
                    items: modalCities
                        .map((city) => DropdownMenuItem(
                            value: city,
                            child: Text(
                                city == 'Todas' ? 'Todas as cidades' : city)))
                        .toList(),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: InkFlowColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            vertical: 18), // Botão gigante e fácil de apertar
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
}
