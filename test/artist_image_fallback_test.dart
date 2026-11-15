import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/core/widgets/shared_widgets.dart';

void main() {
  testWidgets('usa a foto alternativa quando a principal está ausente',
      (tester) async {
    const url = 'https://example.com/portfolio.png';
    await tester.pumpWidget(const MaterialApp(
      home: NetworkImageWithFallback(url: null, fallbackUrls: [url]),
    ));

    final image =
        tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
    expect(image.imageUrl, url);
  });

  testWidgets('tenta outra foto quando a capa e a primeira alternativa falham',
      (tester) async {
    const cover = 'https://example.com/cover.png';
    const first = 'https://example.com/first.png';
    const second = 'https://example.com/second.png';
    await tester.pumpWidget(const MaterialApp(
      home: NetworkImageWithFallback(
        url: cover,
        fallbackUrls: [cover, first, second],
      ),
    ));

    final finder = find.byType(CachedNetworkImage);
    for (final url in [cover, first]) {
      final image = tester.widget<CachedNetworkImage>(finder);
      expect(image.imageUrl, url);
      final fallback =
          image.errorWidget!(tester.element(finder), url, StateError('404'));
      await tester.pumpWidget(MaterialApp(home: fallback));
    }
    expect(tester.widget<CachedNetworkImage>(finder).imageUrl, second);
  });
}
