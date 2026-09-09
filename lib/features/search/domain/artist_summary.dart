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
  final String? bio;
  final int experienceYears;
  final String? studioName;
  final String? instagram;

  const ArtistSummary({
    required this.id,
    required this.name,
    required this.styles,
    required this.rating,
    required this.portfolioUrls,
    this.avatarUrl,
    this.city,
    this.state,
    this.bio,
    this.experienceYears = 0,
    this.studioName,
    this.instagram,
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
      bio: _nonEmpty(row['bio']),
      experienceYears: _experienceYears(row),
      studioName: _nonEmpty(row['studio_name']),
      instagram: _nonEmpty(row['instagram']),
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

  static int _experienceYears(Map<String, dynamic> row) {
    final startYear = int.tryParse(row['career_start_year']?.toString() ?? '');
    if (startYear != null && startYear <= DateTime.now().year) {
      return DateTime.now().year - startYear;
    }
    return int.tryParse(row['experience_years']?.toString() ?? '') ?? 0;
  }
}
