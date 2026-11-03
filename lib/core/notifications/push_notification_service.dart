import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:inkflow/core/data/supabase_providers.dart';
import 'push_subscription.dart';

class PushNotificationService {
  final SupabaseClient _supabase;
  StreamSubscription<AuthState>? _authSubscription;
  bool _initialized = false;
  void Function()? _onPermissionDenied;
  bool _pendingPermissionDenied = false;

  PushNotificationService(this._supabase);

  void setPermissionDeniedHandler(void Function() handler) {
    _onPermissionDenied = handler;
    if (_pendingPermissionDenied) {
      _pendingPermissionDenied = false;
      handler();
    }
  }

  Future<void> initialize() async {
    if (!kIsWeb || _initialized) return;
    _initialized = true;
    await _safeRegisterSubscription();
    _authSubscription = _supabase.auth.onAuthStateChange.listen((state) {
      if (state.session != null) unawaited(_safeRegisterSubscription());
    });
  }

  Future<bool> enable() => _registerSubscription();

  Future<void> _safeRegisterSubscription() async {
    try {
      await _registerSubscription();
    } catch (error) {
      debugPrint('Não foi possível ativar Web Push: $error');
    }
  }

  Future<bool> _registerSubscription() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;
    final response = await http.get(Uri.parse(
      '${_supabase.rest.url.replaceFirst('/rest/v1', '')}/functions/v1/process-push',
    ));
    if (response.statusCode != 200) return false;
    final publicKey =
        (jsonDecode(response.body) as Map<String, dynamic>)['publicKey']
            ?.toString();
    if (publicKey == null || publicKey.isEmpty) return false;

    final result = await subscribeToWebPush(publicKey);
    if (result.permissionDenied) {
      final handler = _onPermissionDenied;
      if (handler == null) {
        _pendingPermissionDenied = true;
      } else {
        handler();
      }
      return false;
    }
    final subscription = result.subscription;
    if (subscription == null) return false;
    await _supabase.from('push_subscriptions').upsert({
      'endpoint': subscription.endpoint,
      'user_id': userId,
      'p256dh': subscription.p256dh,
      'auth_key': subscription.authKey,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'endpoint');
    return true;
  }

  void dispose() => unawaited(_authSubscription?.cancel());
}

Future<void> unregisterPushSubscription(SupabaseClient supabase) async {
  if (!kIsWeb) return;
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return;
  await supabase.from('push_subscriptions').delete().eq('user_id', userId);
  await unsubscribeFromWebPush();
}

final pushNotificationServiceProvider =
    Provider<PushNotificationService>((ref) {
  final service = PushNotificationService(ref.watch(supabaseClientProvider));
  ref.onDispose(service.dispose);
  unawaited(service.initialize());
  return service;
});
