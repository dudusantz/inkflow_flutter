import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/core/widgets/shared_widgets.dart';
import 'package:inkflow/features/profile/data/profile_repository.dart';
import 'package:inkflow/features/profile/presentation/profile_setup_screen.dart';

class _ExistingProfileRepository implements ProfileRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Map<String, dynamic>?> fetchProfessionalSettings() async => {
        'styles': ['Black Work'],
        'min_price': 150,
        'hourly_rate': 200,
        'bio': 'Bio curta',
        'career_start_year': 2010,
        'city': 'Cavalcante',
        'state': 'GO',
        'portfolio_url': 'https://example.com/portfolio.png',
      };
}

void main() {
  testWidgets('permite salvar portfólio existente com bio curta',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        profileRepositoryProvider.overrideWithValue(
          _ExistingProfileRepository(),
        ),
      ],
      child: const MaterialApp(home: ProfileSetupScreen()),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('Bio curta'), findsOneWidget);
    final photo = tester.widget<NetworkImageWithFallback>(
      find.byType(NetworkImageWithFallback),
    );
    expect(photo.url, 'https://example.com/portfolio.png');
    final save = tester.widget<InkButton>(find.widgetWithText(
      InkButton,
      'Salvar alterações',
    ));
    expect(save.onPressed, isNotNull);
  });
}
