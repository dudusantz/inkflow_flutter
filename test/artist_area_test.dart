import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:inkflow/features/home/presentation/artist_home_screen.dart';
import 'package:inkflow/features/profile/domain/user_profile.dart';
import 'package:inkflow/features/profile/presentation/privacy_screen.dart';
import 'package:inkflow/features/profile/providers/profile_provider.dart';
import 'package:inkflow/features/schedule/domain/appointment.dart';

Appointment _appointment({
  required String id,
  required String clientName,
  required String time,
  required double price,
  required String anamnesisStatus,
}) {
  final today = DateTime.now();
  return Appointment.tryFromRow({
    'id': id,
    'artist_id': 'artist-1',
    'client_name': clientName,
    'date':
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
    'time': time,
    'end_time': '23:59',
    'style': 'Geométrico',
    'price': price,
    'status': 'CONFIRMADO',
    'anamnesis_status': anamnesisStatus,
    'reminder_enabled': true,
  })!;
}

List<Appointment> _todayAppointments() => [
      _appointment(
          id: '1',
          clientName: 'Carlos Mendes',
          time: '09:00',
          price: 600,
          anamnesisStatus: 'ok'),
      _appointment(
          id: '2',
          clientName: 'Fernanda Lima',
          time: '12:00',
          price: 800,
          anamnesisStatus: 'pendente'),
      _appointment(
          id: '3',
          clientName: 'Roberto Alves',
          time: '16:30',
          price: 400,
          anamnesisStatus: 'risco'),
    ];

Widget _app(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('pt', 'BR')],
    locale: const Locale('pt', 'BR'),
    home: child,
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('DailySummary', () {
    test('soma receita prevista e conta anamneses pendentes', () {
      final summary = DailySummary.from(_todayAppointments());

      expect(summary.totalSessions, 3);
      expect(summary.expectedRevenue, 1800);
      expect(summary.pendingAnamnesis, 1);
    });

    test('zera tudo quando não há sessões', () {
      final summary = DailySummary.from(const []);

      expect(summary.totalSessions, 0);
      expect(summary.expectedRevenue, 0);
      expect(summary.pendingAnamnesis, 0);
    });
  });

  testWidgets('ArtistHomeScreen exibe métricas e agenda do dia',
      (tester) async {
    // A tela é alta: com o viewport padrão de 800x600 a lista de sessões fica
    // parcialmente fora da área renderizada.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileProvider.overrideWith(
            (ref) async => const UserProfile(
              id: 'artist-1',
              name: 'Ana Tatuadora',
              email: 'ana@inkflow.app',
              role: 'ARTIST',
            ),
          ),
          todayAppointmentsProvider
              .overrideWith((ref) async => _todayAppointments()),
        ],
        child: _app(const ArtistHomeScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Agenda de Hoje'), findsOneWidget);
    expect(find.text('Carlos Mendes'), findsOneWidget);
    expect(find.text('Fernanda Lima'), findsOneWidget);
    expect(find.textContaining('Olá, Ana'), findsOneWidget);
    expect(find.text('R\$ 1800'), findsOneWidget);
  });

  testWidgets('ArtistHomeScreen exibe estado vazio sem agendamentos',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileProvider.overrideWith(
            (ref) async => const UserProfile(
              id: 'artist-1',
              name: 'Ana Tatuadora',
              email: 'ana@inkflow.app',
              role: 'ARTIST',
            ),
          ),
          todayAppointmentsProvider.overrideWith((ref) async => []),
        ],
        child: _app(const ArtistHomeScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Nenhuma sessão agendada para hoje.'), findsOneWidget);
  });

  testWidgets('PrivacyScreen renderiza conteúdo esperado', (tester) async {
    await tester.pumpWidget(_app(const PrivacyScreen()));

    expect(find.text('Privacidade e Segurança'), findsOneWidget);
    expect(find.text('Seus dados'), findsOneWidget);
  });
}
