import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/search/domain/artist_summary.dart';

void main() {
  group('ArtistSummary.fromRow', () {
    test('monta o resumo a partir da view artist_directory', () {
      final artist = ArtistSummary.fromRow({
        'id': 'a1',
        'name': 'Studio Ink',
        'avatar_url': 'https://example.com/avatar.jpg',
        'styles': ['Black Work', 'Realismo'],
        'city': 'Recife',
        'state': 'PE',
        'rating': '4.8',
        'portfolio_urls': ['https://example.com/1.jpg'],
      });

      expect(artist.name, 'Studio Ink');
      expect(artist.location, 'Recife, PE');
      expect(artist.stylesLabel, 'Black Work • Realismo');
      expect(artist.rating, 4.8);
      expect(artist.coverImageUrl, 'https://example.com/1.jpg');
    });

    test('cai no avatar quando não há portfólio', () {
      final artist = ArtistSummary.fromRow({
        'id': 'a1',
        'name': 'Studio Ink',
        'avatar_url': 'https://example.com/avatar.jpg',
        'portfolio_urls': <String>[],
      });

      expect(artist.coverImageUrl, 'https://example.com/avatar.jpg');
    });

    test('inclui portfolio_url legado sem duplicar', () {
      final artist = ArtistSummary.fromRow({
        'id': 'a1',
        'name': 'Studio Ink',
        'portfolio_urls': ['https://example.com/1.jpg'],
        'portfolio_url': 'https://example.com/1.jpg',
      });

      expect(artist.portfolioUrls, ['https://example.com/1.jpg']);
    });

    test('usa textos de fallback quando faltam dados', () {
      final artist = ArtistSummary.fromRow({'id': 'a1'});

      expect(artist.name, 'Tatuador');
      expect(artist.location, 'Local não informado');
      expect(artist.stylesLabel, 'Estilo não definido');
      expect(artist.rating, 5.0);
    });
  });
}
