import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inkflow/core/notifications/push_notification_service.dart';
import 'package:inkflow/main.dart';
import 'package:inkflow/router.dart';

class _NoPush implements PushNotificationService {
  @override
  void setPermissionDeniedHandler(void Function() handler) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('protege a rota e o modal das duas barras do Android',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 800);
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 48);
    addTearDown(tester.view.reset);

    const content = Key('screen-content');
    const sheet = Key('sheet-content');
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: SizedBox.expand(
            key: content,
            child: Center(
              child: TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => const SizedBox(key: sheet, height: 80),
                ),
                child: const Text('Abrir modal'),
              ),
            ),
          ),
        ),
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        routerProvider.overrideWithValue(router),
        pushNotificationServiceProvider.overrideWithValue(_NoPush()),
      ],
      child: const InkFlowApp(),
    ));
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byKey(content));
    expect(rect.top, 24);
    expect(rect.bottom, 752);
    await tester.tap(find.text('Abrir modal'));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(sheet)).bottom, 752);
  }, variant: const TargetPlatformVariant({TargetPlatform.android}));
}
