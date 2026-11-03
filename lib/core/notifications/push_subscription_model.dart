class WebPushSubscription {
  final String endpoint;
  final String p256dh;
  final String authKey;

  const WebPushSubscription({
    required this.endpoint,
    required this.p256dh,
    required this.authKey,
  });
}

class WebPushResult {
  final WebPushSubscription? subscription;
  final bool permissionDenied;

  const WebPushResult({this.subscription, this.permissionDenied = false});
}
