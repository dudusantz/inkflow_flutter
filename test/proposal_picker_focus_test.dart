import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/core/widgets/shared_widgets.dart';
import 'package:inkflow/features/chat/presentation/chat_screen.dart';
import 'package:inkflow/features/profile/providers/profile_provider.dart';

void main() {
  testWidgets('seletores da proposta não devolvem o foco ao valor',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(440, 1000);
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 56);
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      (_) async => null,
    );

    const contact = 'test-contact';
    await tester.pumpWidget(ProviderScope(
      overrides: [
        isArtistProvider.overrideWithValue(true),
        chatStreamProvider(contact).overrideWith((_) => Stream.value([])),
        chatContactProvider(contact).overrideWith((_) async => null),
      ],
      child: const MaterialApp(home: ChatScreen(contactId: contact)),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Enviar proposta'));
    await tester.pumpAndSettle();

    final value = find.widgetWithText(TextFormField, '0,00');
    final editable =
        find.descendant(of: value, matching: find.byType(EditableText));
    for (final picker in ['Escolher data', 'Escolher horário']) {
      await tester.enterText(value, '130');
      expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isTrue);
      await tester.tap(find.text(picker));
      await tester.pumpAndSettle();
      if (picker == 'Escolher data') {
        await tester.tap(find.text('${DateTime.now().day}').last);
      }
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      final field = tester.widget<EditableText>(editable);
      expect(field.focusNode.hasFocus, isFalse);
      expect(field.controller.text, '130');
    }

    final send = find.widgetWithText(InkButton, 'Enviar proposta');
    await tester.ensureVisible(send);
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(send).dy, lessThanOrEqualTo(944));
  });
}
