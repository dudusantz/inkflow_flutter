import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'push_subscription_model.dart';

Future<WebPushResult> subscribeToWebPush(String publicKey) async {
  final permission = (await web.Notification.requestPermission().toDart).toDart;
  if (permission != 'granted') {
    return const WebPushResult(permissionDenied: true);
  }

  final registration = await web.window.navigator.serviceWorker
      .register(
        '/push-sw.js'.toJS,
        web.RegistrationOptions(scope: '/push/'),
      )
      .toDart;
  final existing = await registration.pushManager.getSubscription().toDart;
  final key = base64Url.decode(base64Url.normalize(publicKey)).toJS;
  final subscription = existing ??
      await registration.pushManager
          .subscribe(web.PushSubscriptionOptionsInit(
            userVisibleOnly: true,
            applicationServerKey: key,
          ))
          .toDart;
  final json = subscription.toJSON().dartify() as Map;
  final keys = json['keys'] as Map;
  return WebPushResult(
    subscription: WebPushSubscription(
      endpoint: subscription.endpoint,
      p256dh: keys['p256dh'].toString(),
      authKey: keys['auth'].toString(),
    ),
  );
}

Future<void> unsubscribeFromWebPush() async {
  final registration =
      await web.window.navigator.serviceWorker.getRegistration('/push/').toDart;
  final subscription = await registration?.pushManager.getSubscription().toDart;
  await subscription?.unsubscribe().toDart;
}
