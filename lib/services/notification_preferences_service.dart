import 'package:shared_preferences/shared_preferences.dart';

/// Which Notification Center items the current device has already read —
/// device-local UI state, not shared business data, so it lives in
/// [SharedPreferences] rather than Firestore. Mirrors `SettingsService`'s
/// own reasoning for the same storage choice. See ADR-007.
class NotificationPreferencesService {
  NotificationPreferencesService(this._prefs);

  final SharedPreferences _prefs;

  static const _readIdsKey = 'notif_read_ids';

  Set<String> get readIds => _prefs.getStringList(_readIdsKey)?.toSet() ?? {};

  Future<void> markRead(String id) {
    return _prefs.setStringList(_readIdsKey, {...readIds, id}.toList());
  }

  Future<void> markAllRead(Iterable<String> ids) {
    return _prefs.setStringList(_readIdsKey, {...readIds, ...ids}.toList());
  }
}
