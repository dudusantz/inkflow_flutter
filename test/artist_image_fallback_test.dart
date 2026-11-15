import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/core/widgets/shared_widgets.dart';

void main() {
  testWidgets('usa a foto alternativa quando a principal está ausente',
      (tester) async {
    const url = 'https://example.com/portfolio.png';
    await tester.pumpWidget(const MaterialApp(
      home: NetworkImageWithFallback(url: null, fallbackUrl: url),
    ));

    final image =
        tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
    expect(image.imageUrl, url);
  });
}
