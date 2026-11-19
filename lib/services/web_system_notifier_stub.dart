/// Non-web builds: browser notifications don't apply (Android uses
/// flutter_local_notifications instead — see PushNotificationService).
Future<bool> showWebSystemNotification({
  required String title,
  required String body,
  required String tag,
  required String link,
  required bool sticky,
}) async => false;

void listenForWebNotificationClicks(void Function(String link) onOpen) {}
