import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

// 1. PROVIDER DOS ESTÚDIOS EM ALTA
final trendingArtistsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final supabase = Supabase.instance.client;
    final response = await supabase
        .from('profiles')
        .select('name, style, rating, avatar_url')
        .eq('role', 'ARTIST')
        .limit(5);
    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    return [];
  }
});

// 2. PROVIDER DA PRÓXIMA SESSÃO (DADOS REAIS)
final nextSessionProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  try {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    // Se houver um usuário real logado, filtra pelo ID dele.
    // Como estamos no Bypass (user == null), ele vai tentar buscar a sessão mais recente geral
    // apenas para você ter o que printar. No mundo real, descomente o '.eq()' abaixo.

    final response = await supabase
        .from(
            'appointments') // ⚠️ Verifique se sua tabela de agenda se chama 'appointments' ou mude aqui
        .select('date, time, style, status, profiles(name)')
        // .eq('client_id', user?.id ?? '') // Filtro real do cliente
        .gte('date', DateTime.now().toIso8601String()) // Apenas sessões futuras
        .order('date', ascending: true)
        .limit(1)
        .maybeSingle();

    return response;
  } catch (e) {
    // Retorna nulo se a tabela não existir ainda ou der erro, ativando o "Empty State"
    return null;
  }
});

class ClientHomeScreen extends ConsumerStatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  ConsumerState<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends ConsumerState<ClientHomeScreen> {
  int _currentIndex = 0;

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Funcionalidade em desenvolvimento 🚀'),
        backgroundColor: InkFlowColors.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F5),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildHeader(),
            _buildQuickActions(),
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSearchBar(),
                    const SizedBox(height: 32),

                    _buildSectionTitle('Minha Próxima Sessão', 'Ver detalhes',
                        () => context.go('/schedule')),
                    const SizedBox(height: 16),
                    _buildNextSessionSection(), // Agora consome dados do Supabase

                    const SizedBox(height: 32),

                    _buildSectionTitle('Estúdios em Alta', 'Explorar',
                        () => context.go('/search')),
                    const SizedBox(height: 16),
                    _buildRecommendedArtists(),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // --- CABEÇALHO ---
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 20, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [InkFlowColors.primary, Color(0xFF1F2937)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Image.asset('assets/inkflow_logo.png',
                  height: 32,
                  errorBuilder: (c, e, s) => const Icon(Icons.water_drop,
                      color: Colors.white, size: 32)),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined,
                        color: Colors.white),
                    onPressed: _showComingSoon,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: InkFlowColors.accent, width: 2),
                    ),
                    child: const CircleAvatar(
                      radius: 18,
                      backgroundImage: NetworkImage(
                          'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100&h=100&fit=crop'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Olá, Eduardo 👋',
            style: TextStyle(
                color: Color(0x99FFFFFF),
                fontSize: 15,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          const Text(
            'Encontre seu próximo estilo.',
            style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5),
          ),
        ],
      ),
    );
  }

  // --- AÇÕES RÁPIDAS ---
  Widget _buildQuickActions() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _actionButton(
              Icons.explore_outlined, 'Explorar', () => context.go('/search')),
          _actionButton(Icons.favorite_border, 'Favoritos', _showComingSoon),
          _actionButton(
              Icons.medical_information_outlined, 'Cuidados', _showComingSoon),
          _actionButton(Icons.chat_bubble_outline, 'Mensagens',
              () => context.go('/chat')),
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
              color: InkFlowColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: InkFlowColors.accent, size: 26),
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

  // --- BUSCA ---
  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () => context.go('/search'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5))
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: InkFlowColors.accent, size: 22),
            const SizedBox(width: 12),
            Text('Buscar estúdios, artistas ou estilos...',
                style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // --- TÍTULOS ---
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
                  color: InkFlowColors.accent)),
        ),
      ],
    );
  }

  // --- SESSÃO (REATIVA AO SUPABASE) ---
  Widget _buildNextSessionSection() {
    final sessionAsync = ref.watch(nextSessionProvider);

    return sessionAsync.when(
      data: (session) {
        // Se o banco retornar nulo ou vazio, mostra o "Empty State"
        if (session == null || session.isEmpty) {
          return _buildEmptySessionCard();
        }

        // Tratamento da data vinda do banco
        final dateStr = session['date'] as String?;
        DateTime? date;
        if (dateStr != null) date = DateTime.tryParse(dateStr);

        // Pega o idioma pt_BR se o intl estiver configurado, ou usa padrão
        final month = date != null
            ? DateFormat('MMM', 'pt_BR').format(date).toUpperCase()
            : 'MÊS';
        final day = date != null ? DateFormat('dd').format(date) : '--';

        final style = session['style'] ?? 'Tatuagem';
        final time = session['time'] ?? 'A definir';
        final status = session['status'] ?? 'Confirmado';

        // Tenta buscar o nome do artista do join na tabela profiles
        String artistName = 'Estúdio parceiro';
        if (session['profiles'] != null && session['profiles'] is Map) {
          artistName = session['profiles']['name'] ?? artistName;
        }

        return _buildNextSessionCard(
            month, day, style, artistName, time, status);
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
            child: CircularProgressIndicator(color: InkFlowColors.accent)),
      ),
      error: (e, s) =>
          _buildEmptySessionCard(), // Se der erro de tabela não criada, mostra vazio
    );
  }

  // Card com Dados Reais
  Widget _buildNextSessionCard(String month, String day, String style,
      String artistName, String time, String status) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
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
              borderRadius: BorderRadius.circular(16),
            ),
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
                Text('Sessão - $style',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: InkFlowColors.primary)),
                const SizedBox(height: 4),
                Text('Com $artistName',
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time_filled,
                        size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text(time,
                        style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(status.toUpperCase(),
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF059669))),
          ),
        ],
      ),
    );
  }

  // Card "Empty State" (Quando não há sessões no banco)
  Widget _buildEmptySessionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
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
          Text(
            'Sua pele está em branco. Que tal encontrar uma inspiração?',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.go('/search'),
            style: ElevatedButton.styleFrom(
              backgroundColor: InkFlowColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Explorar Estúdios',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- ARTISTAS EM ALTA ---
  Widget _buildRecommendedArtists() {
    final artistsAsync = ref.watch(trendingArtistsProvider);

    return artistsAsync.when(
      data: (artists) {
        if (artists.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('Nenhum estúdio cadastrado ainda.',
                style: TextStyle(color: Colors.grey, fontSize: 14)),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: artists.map((artist) {
              return _artistCard(
                artist['name'] ?? 'Estúdio Real',
                artist['style'] ?? 'Blackwork / Realismo',
                artist['rating']?.toString() ?? '5.0',
                artist['avatar_url'] ??
                    'https://images.unsplash.com/photo-1611501275019-9b5cda994e8d?w=300&fit=crop',
              );
            }).toList(),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
            child: CircularProgressIndicator(color: InkFlowColors.accent)),
      ),
      error: (error, stack) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text('Erro ao conectar com o banco de dados.',
            style: TextStyle(color: Colors.red)),
      ),
    );
  }

  Widget _artistCard(
      String name, String style, String rating, String imageUrl) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.network(
              imageUrl,
              height: 110,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 110,
                color: Colors.grey.shade200,
                child:
                    const Icon(Icons.image_not_supported, color: Colors.grey),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
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
                const SizedBox(height: 2),
                Text(style,
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star, color: Color(0xFFF59E0B), size: 16),
                    const SizedBox(width: 4),
                    Text(rating,
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

  // --- NAVEGAÇÃO ---
  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        setState(() => _currentIndex = index);
        if (index == 1) context.go('/schedule');
        if (index == 2) context.go('/chat');
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: InkFlowColors.accent,
      unselectedItemColor: const Color(0xFF9CA3AF),
      selectedFontSize: 12,
      unselectedFontSize: 12,
      elevation: 20,
      backgroundColor: Colors.white,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Início'),
        BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined), label: 'Agenda'),
        BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
        BottomNavigationBarItem(
            icon: Icon(Icons.person_outline), label: 'Perfil'),
      ],
    );
  }
}
