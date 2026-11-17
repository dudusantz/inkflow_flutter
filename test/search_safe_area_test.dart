import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/search/domain/artist_summary.dart';
import 'package:inkflow/features/search/presentation/search_screen.dart';

void main() {
  testWidgets('explorar respeita a barra do sistema e aplica o estilo ao tocar',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 660);
    tester.view.padding = const FakeViewPadding(bottom: 48);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        artistsSearchProvider.overrideWith((_) async => const [
              ArtistSummary(
                id: 'artist',
                name: 'Artista',
                styles: ['Black Work'],
                rating: 5,
                portfolioUrls: [],
              ),
              ArtistSummary(
                id: 'outro',
                name: 'Outro artista',
                styles: ['Realismo'],
                rating: 4,
                portfolioUrls: [],
              ),
            ]),
      ],
      child: const MaterialApp(home: SearchScreen()),
    ));
    await tester.pumpAndSettle();

    final scroll = find.byType(CustomScrollView);
    expect(tester.getBottomLeft(scroll).dy, 612);
    await tester.tap(find.text('Black Work').first);
    await tester.pumpAndSettle();
    expect(find.text('1 profissional'), findsOneWidget);

    await tester.tap(find.text('Todos'));
    await tester.pumpAndSettle();
    expect(find.text('2 profissionais'), findsOneWidget);

    final header = find.text('Buscar Tatuadores');
    final headerBefore = tester.getTopLeft(header).dy;
    await tester.drag(scroll, const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(header).dy, lessThan(headerBefore));
  });
}
