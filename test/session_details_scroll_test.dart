import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/profile/providers/profile_provider.dart';
import 'package:inkflow/features/schedule/domain/appointment.dart';
import 'package:inkflow/features/schedule/presentation/schedule_screen.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('detalhes com nome longo permitem rolar até fechar',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 800);
    addTearDown(tester.view.reset);
    const name = 'Anthony Guilherme José da Paz e Silva';

    await tester.pumpWidget(ProviderScope(
      overrides: [
        isArtistProvider.overrideWithValue(true),
        scheduleProvider.overrideWith((_) async => [
              Appointment(
                id: 'session',
                artistId: 'artist',
                clientName: name,
                date: DateTime.now(),
                startTime: '18:57',
                endTime: '19:57',
                style: 'Black Work',
                price: 100,
                status: 'Confirmado',
                anamnesisStatus: 'assinado',
                reminderEnabled: true,
              ),
            ]),
      ],
      child: const MaterialApp(home: ScheduleScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(420, 400);
    await tester.pumpAndSettle();
    final close = find.text('Fechar Detalhes');
    await tester.ensureVisible(close);
    await tester.pumpAndSettle();
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });
}
