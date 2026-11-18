import 'package:cloud_firestore/cloud_firestore.dart';

/// One device registered for push alerts — a `deviceTokens/{token}` doc.
///
/// [platform] is how the app runs there (`web`, `android`, `iOS`, or
/// `unknown` for devices moved from the old per-user location); [os] is the
/// operating system underneath (`windows`, `android`, `macOS`, ...), so a
/// browser on a phone reads as "Browser · Android" and a desk PC as
/// "Browser · Windows". [lastSentAt] is when the server last handed an alert
/// for this device to Firebase Cloud Messaging (written by the Cloud
/// Functions).
class DeviceRegistration {
  const DeviceRegistration({
    required this.token,
    required this.uid,
    required this.platform,
    required this.os,
    this.updatedAt,
    this.lastSentAt,
    this.lastSentType,
  });

  factory DeviceRegistration.fromMap(String id, Map<String, dynamic> data) {
    return DeviceRegistration(
      token: id,
      uid: data['uid'] as String? ?? '',
      platform: data['platform'] as String? ?? 'unknown',
      os: data['os'] as String? ?? 'unknown',
      updatedAt: _date(data['updatedAt']),
      lastSentAt: _date(data['lastSentAt']),
      lastSentType: data['lastSentType'] as String?,
    );
  }

  final String token;
  final String uid;
  final String platform;
  final String os;
  final DateTime? updatedAt;
  final DateTime? lastSentAt;
  final String? lastSentType;

  bool get isWeb => platform == 'web';

  static DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

/// Human-readable device label, e.g. "Browser · Windows", "Android app".
String deviceLabel(String platform, String os) {
  final String osName = switch (os.toLowerCase()) {
    'windows' => 'Windows',
    'macos' => 'Mac',
    'linux' => 'Linux',
    'android' => 'Android',
    'ios' => 'iPhone/iPad',
    'fuchsia' => 'Fuchsia',
    _ => '',
  };
  return switch (platform.toLowerCase()) {
    'web' => osName.isEmpty ? 'Browser' : 'Browser · $osName',
    'android' => 'Android app',
    'ios' => 'iPhone app',
    _ => 'Device (registered before this update)',
  };
}
