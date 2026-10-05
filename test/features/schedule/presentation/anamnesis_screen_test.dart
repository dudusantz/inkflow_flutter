import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/core/theme/app_theme.dart';
import 'package:inkflow/features/schedule/presentation/anamnesis_screen.dart';

void main() {
  testWidgets('organiza a anamnese em seções e exige respostas explícitas',
      (tester) async {
    tester.view.physicalSize = const Size(383, 838);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: InkFlowTheme.theme,
          home: const AnamnesisScreen(proposalId: 'proposal-1'),
        ),
      ),
    );

    expect(find.text('Saúde geral'), findsOneWidget);
    expect(find.text('Pele e cicatrização'), findsOneWidget);
    expect(find.text('Condições importantes'), findsOneWidget);
    expect(find.text('Contato de emergência'), findsOneWidget);
    expect(find.text('Declaração e assinatura'), findsOneWidget);

    await tester.tap(find.text('Revisar respostas'));
    await tester.pump();

    expect(
      find.text('Responda todas as perguntas antes de continuar.'),
      findsOneWidget,
    );
    expect(find.text('Selecione uma resposta'), findsNWidgets(9));
  });
}
