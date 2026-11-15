import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/finance/data/finance_repository.dart';
import 'package:inkflow/features/finance/presentation/studio_management_screen.dart';

void main() {
  testWidgets('fecha a aba de despesa com os campos ainda montados',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [financialRecordsProvider.overrideWith((_) async => [])],
      child: const MaterialApp(home: StudioManagementScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Despesa'));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    expect(sheet, findsOneWidget);

    final top = tester.getTopLeft(sheet);
    await tester.dragFrom(top + const Offset(150, 10), const Offset(0, 400));
    await tester.pumpAndSettle();

    expect(sheet, findsNothing);
    expect(tester.takeException(), isNull);
  });
}
