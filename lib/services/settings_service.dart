import 'package:flutter/material.dart';
import 'package:jva_projecttracker/theme/app_font.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local personalization preferences (theme mode, font, language).
/// These are personal display preferences, not shared business data, so they
/// live in [SharedPreferences] rather than the user's Firestore profile.
class SettingsService {
  SettingsService(this._prefs);

  final SharedPreferences _prefs;

  static const _themeModeKey = 'pref_theme_mode';
  static const _fontKey = 'pref_font';
  static const _localeKey = 'pref_locale';

  ThemeMode get themeMode {
    final stored = _prefs.getString(_themeModeKey);
    return ThemeMode.values.firstWhere(
      (m) => m.name == stored,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _prefs.setString(_themeModeKey, mode.name);

  AppFont get font => AppFontX.fromName(_prefs.getString(_fontKey) ?? '');

  Future<void> setFont(AppFont font) => _prefs.setString(_fontKey, font.name);

  /// Defaults to English until the user explicitly switches in Settings.
  Locale get locale => Locale(_prefs.getString(_localeKey) ?? 'en');

  Future<void> setLocale(Locale locale) =>
      _prefs.setString(_localeKey, locale.languageCode);
}
