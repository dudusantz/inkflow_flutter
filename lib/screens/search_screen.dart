import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

const _styles = ['Black Work', 'Realismo', 'Geométrico', 'Aquarela', 'Old School', 'Minimalista'];
const _locations = ['São Paulo, SP', 'Rio de Janeiro, RJ', 'Belo Horizonte, MG', 'Curitiba, PR'];

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final List<String> _selectedStyles = [];
  String _selectedLocation = '';
  
  bool _searched = false;
  bool _showError = false;

  // Lista simulando o banco de dados (que substituirá os mocks)
  final List<Map<String, dynamic>> _allArtists = [
    {
      'id': 1,
      'name': 'Ana Ferreira',
      'location': 'São Paulo, SP',
      'styles': ['Black Work', 'Geométrico'],
      'rating': 4.9,
      'reviews': 128,
      'price': 'A partir de R\$ 300',
      'avatar': 'https://images.unsplash.com/photo-1612271974453-15e684c6586b?w=80&h=80&fit=crop&crop=face',
      'portfolio': 'https://images.unsplash.com/photo-1645318588650-f0fb322cd740?w=160&h=100&fit=crop',
    },
    {
      'id': 2,
      'name': 'Rafael Costa',
      'location': 'Curitiba, PR',
      'styles': ['Realismo', 'Old School'],
      'rating': 4.7,
      'reviews': 94,
      'price': 'A partir de R\$ 450',
      'avatar': 'https://images.unsplash.com/photo-1544604725-0ffa9861dec2?w=80&h=80&fit=crop&crop=face',
      'portfolio': 'https://images.unsplash.com/photo-1645542335615-3acf176850bc?w=160&h=100&fit=crop',
    },
  ];

  List<Map<String, dynamic>> _filteredArtists = [];

  void _toggleStyle(String s) {
    setState(() {
      if (_selectedStyles.contains(s)) {
        _selectedStyles.remove(s);
      } else {
        _selectedStyles.add(s);
      }
    });
  }

  void _handleSearch() {
    // Bloqueia a busca se não houver filtros (RF03 Cenário Negativo)
    if (_selectedStyles.isEmpty && _selectedLocation.isEmpty) {
      setState(() {
        _showError = true;
        _searched = false;
      });
      return;
    } 

    setState(() {
      _showError = false;
      _searched = true;
      
      // Lógica real de filtro
      _filteredArtists = _allArtists.where((artist) {
        final matchLocation = _selectedLocation.isEmpty || artist['location'] == _selectedLocation;
        final matchStyle = _selectedStyles.isEmpty || _selectedStyles.any((style) => (artist['styles'] as List).contains(style));
        return matchLocation && matchStyle;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header escuro
          Container(
            color: InkFlowColors.primary,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  AppHeader(
                      title: 'Buscar Tatuadores',
                      showBack: true,
                      backTo: '/home',
                      dark: true),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: TextField(
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Nome do tatuador ou estilo...',
                          hintStyle:
                              TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
                          prefixIcon: Icon(Icons.search,
                              color: Colors.white.withOpacity(0.4)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Estilos
                  _label('Estilo'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _styles.map((s) {
                      final sel = _selectedStyles.contains(s);
                      return GestureDetector(
                        onTap: () => _toggleStyle(s),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel ? InkFlowColors.accent : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel
                                  ? InkFlowColors.accent
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Text(
                            s,
                            style: TextStyle(
                              color: sel ? InkFlowColors.primary : Colors.grey.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Localização
                  _label('Localização'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _locations.map((loc) {
                      final sel = _selectedLocation == loc;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedLocation = sel ? '' : loc),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel ? InkFlowColors.primary : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel
                                  ? InkFlowColors.primary
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Text(
                            loc,
                            style: TextStyle(
                              color: sel ? Colors.white : Colors.grey.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Erro de validação
                  if (_showError)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFFEF4444).withOpacity(0.3)),
                      ),
                      child: const Text(
                        '⚠ Por favor, selecione ao menos um estilo ou localização para buscar',
                        style: TextStyle(
                            color: Color(0xFFEF4444), fontSize: 12),
                      ),
                    ),

                  // Botão buscar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _handleSearch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: InkFlowColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Buscar',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Resultados
                  if (_searched && !_showError) ...[
                    Row(
                      children: [
                        _label('Resultados'),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: InkFlowColors.accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_filteredArtists.length} tatuadores',
                            style: const TextStyle(
                                color: InkFlowColors.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    if (_filteredArtists.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: Text('Nenhum profissional encontrado com esses critérios.', style: TextStyle(color: Colors.grey)),
                        ),
                      )
                    else
                      ..._filteredArtists.map((a) => _artistCard(context, a)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Text(text,
        style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 12,
            fontWeight: FontWeight.bold)); // CORRIGIDO AQUI DE TRUE PARA FontWeight.bold
  }

  Widget _artistCard(BuildContext context, Map<String, dynamic> a) {
    final styles = (a['styles'] as List).cast<String>();
    return GestureDetector(
      onTap: () => context.go('/chat?artistId=${a['id']}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Portfolio preview
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                a['portfolio'] as String,
                width: double.infinity,
                height: 100,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(height: 100, color: Colors.grey.shade200),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AvatarImage(url: a['avatar'] as String, size: 40),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a['name'] as String,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14)),
                            Text(a['location'] as String,
                                style: TextStyle(
                                    color: Colors.grey.shade500, fontSize: 11)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.star,
                                  color: Color(0xFFFBBF24), size: 14),
                              const SizedBox(width: 2),
                              Text('${a['rating']}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600, fontSize: 13)),
                            ],
                          ),
                          Text('${a['reviews']} avaliações',
                              style: TextStyle(
                                  color: Colors.grey.shade400, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: styles.map((s) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: InkFlowColors.accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(s,
                            style: const TextStyle(
                                color: InkFlowColors.accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w500)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(a['price'] as String,
                          style: const TextStyle(
                              color: InkFlowColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: InkFlowColors.accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Ver perfil',
                            style: TextStyle(
                                color: InkFlowColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
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