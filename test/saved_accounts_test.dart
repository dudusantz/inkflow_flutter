import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/auth/data/saved_accounts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, dynamic> _session(String id) {
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({
        'sub': id,
        'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
      })))
      .replaceAll('=', '');
  return {
    'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.signature',
    'refresh_token': 'refresh-$id',
    'token_type': 'bearer',
    'expires_in': 3600,
    'user': {
      'id': id,
      'email': '$id@example.com',
      'aud': 'authenticated',
      'user_metadata': {'name': 'Perfil $id'},
    },
  };
}

void main() {
  test('alterna contas, preserva a atual em falha e permite remover uma salva',
      () async {
    FlutterSecureStorage.setMockInitialValues({});
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var rejectRefresh = false;
    server.listen((request) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
      final refreshing =
          request.uri.queryParameters['grant_type'] == 'refresh_token';
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path.endsWith('/signup')) {
        expect(body['code_challenge'], isA<String>());
        request.response.write(jsonEncode({
          'id': 'pendente',
          'email': 'pendente@example.com',
          'aud': 'authenticated',
        }));
      } else if (refreshing && rejectRefresh) {
        request.response.statusCode = 400;
        request.response.write(jsonEncode({'msg': 'Sessão expirada'}));
      } else {
        final id = refreshing
            ? (body['refresh_token'] as String).substring('refresh-'.length)
            : (body['email'] as String).split('@').first;
        request.response.write(jsonEncode(_session(id)));
      }
      await request.response.close();
    });

    final client = SupabaseClient('http://127.0.0.1:${server.port}', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    addTearDown(client.dispose);
    await client.auth.recoverSession(jsonEncode(_session('cliente')));
    final accounts = SavedAccounts(client);
    var cleared = 0;
    Future<void> clear() async => cleared++;

    await accounts.add('artista@example.com', 'senha-teste',
        clearReminders: clear);
    expect(client.auth.currentUser?.id, 'artista');
    expect((await accounts.list()).single.id, 'cliente');
    expect((await accounts.list()).single.name, 'Perfil cliente');

    rejectRefresh = true;
    await expectLater(accounts.switchTo('cliente', clearReminders: clear),
        throwsA(isA<AuthException>()));
    expect(client.auth.currentUser?.id, 'artista');
    expect(cleared, 1);

    rejectRefresh = false;
    await accounts.switchTo('cliente', clearReminders: clear);
    expect(client.auth.currentUser?.id, 'cliente');
    expect(cleared, 2);
    await accounts.forget('artista');
    expect(await accounts.list(), isEmpty);

    final signedIn = await accounts.register(
      (auth) => auth.signUp(
        email: 'pendente@example.com',
        password: 'senha-teste',
      ),
      clearReminders: clear,
    );
    expect(signedIn, isFalse);
    expect(client.auth.currentUser?.id, 'cliente');
    expect(cleared, 2);
  });
}
