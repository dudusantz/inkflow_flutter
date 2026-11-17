import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

bool get supportsAccountSwitching =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

final accountSwitchGeneration = ValueNotifier(0);

class SavedAccounts {
  final SupabaseClient client;
  final FlutterSecureStorage storage;

  const SavedAccounts(this.client,
      {this.storage = const FlutterSecureStorage()});

  String get _prefix => 'inkflow.accounts.${client.rest.url}.';

  Future<List<({String id, String email, String? name})>> list() async {
    final entries = await storage.readAll();
    return [
      for (final entry in entries.entries)
        if (entry.key.startsWith(_prefix))
          if (Session.fromJson(jsonDecode(entry.value)) case final session?)
            if (session.user.id != client.auth.currentUser?.id)
              (
                id: session.user.id,
                email: session.user.email ?? 'Conta InkFlow',
                name: session.user.userMetadata?['name']?.toString().trim(),
              ),
    ];
  }

  Future<void> forget(String id) => storage.delete(key: '$_prefix$id');

  Future<void> switchTo(
    String id, {
    required Future<void> Function() clearReminders,
  }) async {
    final encoded = await storage.read(key: '$_prefix$id');
    final saved =
        encoded == null ? null : Session.fromJson(jsonDecode(encoded));
    final token = saved?.refreshToken;
    if (token == null || saved?.user.id != id) {
      throw const AuthException('Adicione esta conta novamente.');
    }
    await _changeAccount(
      (auth) async {
        final result = await auth.setSession(token);
        if (result.user?.id != id) {
          throw const AuthException('Adicione esta conta novamente.');
        }
        return result;
      },
      clearReminders,
    );
  }

  Future<void> add(
    String email,
    String password, {
    required Future<void> Function() clearReminders,
  }) =>
      _changeAccount(
        (auth) => auth.signInWithPassword(
          email: email.trim().toLowerCase(),
          password: password,
        ),
        clearReminders,
      );

  Future<bool> register(
    Future<AuthResponse> Function(GoTrueClient) signUp, {
    required Future<void> Function() clearReminders,
  }) =>
      _changeAccount(signUp, clearReminders, allowPendingConfirmation: true);

  Future<bool> _changeAccount(
    Future<AuthResponse> Function(GoTrueClient) authenticate,
    Future<void> Function() clearReminders, {
    bool allowPendingConfirmation = false,
  }) async {
    final previousId = client.auth.currentUser?.id;
    if (previousId == null) throw AuthSessionMissingException();

    // A failed refresh must not clear the app's active session.
    final publicKey = client.auth.headers['apikey']!;
    final auth = GoTrueClient(
      url: client.rest.url.replaceFirst(RegExp(r'/rest/v1/?$'), '/auth/v1'),
      headers: {'apikey': publicKey, 'Authorization': 'Bearer $publicKey'},
      autoRefreshToken: false,
      // Keep the confirmation link from authenticating the main client.
      asyncStorage: _TemporaryAuthStorage(),
    );
    try {
      final next = (await authenticate(auth)).session;
      final current = client.auth.currentSession;
      if (current == null || current.user.id != previousId) {
        throw AuthSessionMissingException();
      }
      if (next == null) {
        if (!allowPendingConfirmation) throw AuthSessionMissingException();
        return false;
      }
      await _save(next);
      if (next.user.id != previousId) {
        await _save(current);
        await clearReminders();
      }
      await client.auth.recoverSession(jsonEncode(next.toJson()));
      accountSwitchGeneration.value++;
      return true;
    } finally {
      auth.dispose();
    }
  }

  Future<void> _save(Session session) => storage.write(
        key: '$_prefix${session.user.id}',
        value: jsonEncode(session.toJson()),
      );
}

class _TemporaryAuthStorage extends GotrueAsyncStorage {
  final _values = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => _values[key];

  @override
  Future<void> setItem({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _values.remove(key);
  }
}
