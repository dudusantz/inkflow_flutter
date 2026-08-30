/// Tatuador como ele aparece na vitrine publica.
///
/// Mapeia a view `artist_directory`, que expoe apenas colunas divulgaveis —
/// nunca `cpf`, `phone`, `date_of_birth` ou `guardian_cpf`.
class ArtistSummary {
  final String id;
  final String name;
  final String? avatarUrl;
  final List<String> styles;
  final String? city;
  final String? state;
  final double rating;
  final List<String> portfolioUrls;

  const ArtistSummary({
    required this.id,
    required this.name,
    required this.styles,
    required this.rating,
    required this.portfolioUrls,
    this.avatarUrl,
    this.city,
    this.state,
  });

  factory ArtistSummary.fromRow(Map<String, dynamic> row) {
    final portfolio = _stringList(row['portfolio_urls']);
    final single = _nonEmpty(row['portfolio_url']);
    if (single != null && !portfolio.contains(single)) {
      portfolio.insert(0, single);
    }

    return ArtistSummary(
      id: row['id'].toString(),
      name: _nonEmpty(row['name']) ?? 'Tatuador',
      avatarUrl: _nonEmpty(row['avatar_url']),
      styles: _stringList(row['styles']),
      city: _nonEmpty(row['city']),
      state: _nonEmpty(row['state']),
      rating: double.tryParse(row['rating']?.toString() ?? '') ?? 5.0,
      portfolioUrls: portfolio,
    );
  }

  /// Primeira imagem util para o card: portfolio tem prioridade sobre o avatar.
  String? get coverImageUrl =>
      portfolioUrls.isNotEmpty ? portfolioUrls.first : avatarUrl;

  String get location {
    if (city != null && state != null) return '$city, $state';
    return city ?? state ?? 'Local não informado';
  }

  String get stylesLabel =>
      styles.isEmpty ? 'Estilo não definido' : styles.join(' • ');

  static List<String> _stringList(dynamic value) {
    if (value is! List) return <String>[];
    return value
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static String? _nonEmpty(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}
