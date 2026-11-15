import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inkflow/features/chat/domain/chat_message.dart';
import 'package:inkflow/features/search/presentation/artist_profile_screen.dart';

void main() {
  testWidgets('mostra o contato fora da vitrine e volta à conversa',
      (tester) async {
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: TextButton(
            onPressed: () => context.push('/contact'),
            child: const Text('Conversa'),
          ),
        ),
      ),
      GoRoute(
        path: '/contact',
        builder: (_, __) => const ArtistProfileScreen(
          artistId: 'client',
          chatContact: ChatContact(id: 'client', name: 'Contato do chat'),
        ),
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        publicArtistProvider('client').overrideWith((_) async => null)
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.tap(find.text('Conversa'));
    await tester.pumpAndSettle();
    expect(find.text('Contato do chat'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Conversa'), findsOneWidget);
  });
}
