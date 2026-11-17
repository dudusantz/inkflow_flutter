import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/core/widgets/shared_widgets.dart';
import 'package:inkflow/features/home/presentation/client_home_screen.dart';
import 'package:inkflow/features/profile/providers/profile_provider.dart';

void main() {
  testWidgets('atalhos rolam e navegação inferior fica no lugar',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(380, 660);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        userProfileProvider.overrideWith((_) async => null),
        nextSessionProvider.overrideWith((_) async => null),
        trendingArtistsProvider.overrideWith((_) async => []),
      ],
      child: const MaterialApp(home: ClientHomeScreen()),
    ));
    await tester.pumpAndSettle();

    final shortcut = find.text('Favoritos');
    final nav = find.byType(AppBottomNav);
    final shortcutBefore = tester.getTopLeft(shortcut);
    final navBefore = tester.getTopLeft(nav);
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -180));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(shortcut).dy, lessThan(shortcutBefore.dy));
    expect(tester.getTopLeft(nav), navBefore);
  });
}
