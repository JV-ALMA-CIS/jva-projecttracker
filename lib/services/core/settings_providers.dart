import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/services/settings_service.dart';
import 'package:jva_projecttracker/theme/app_font.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in `main()` with the resolved [SharedPreferences] instance
/// before the app is run.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

final settingsServiceProvider = Provider(
  (ref) => SettingsService(ref.watch(sharedPreferencesProvider)),
);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.watch(settingsServiceProvider).themeMode;

  void update(ThemeMode mode) {
    state = mode;
    ref.read(settingsServiceProvider).setThemeMode(mode);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class AppFontController extends Notifier<AppFont> {
  @override
  AppFont build() => ref.watch(settingsServiceProvider).font;

  void update(AppFont font) {
    state = font;
    ref.read(settingsServiceProvider).setFont(font);
  }
}

final appFontProvider = NotifierProvider<AppFontController, AppFont>(
  AppFontController.new,
);

class AppLocaleController extends Notifier<Locale> {
  @override
  Locale build() => ref.watch(settingsServiceProvider).locale;

  void update(Locale locale) {
    state = locale;
    ref.read(settingsServiceProvider).setLocale(locale);
  }
}

final appLocaleProvider = NotifierProvider<AppLocaleController, Locale>(
  AppLocaleController.new,
);
