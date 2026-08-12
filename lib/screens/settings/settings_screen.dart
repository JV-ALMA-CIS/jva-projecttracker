import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_font.dart';
import 'package:jva_projecttracker/widgets/section_header.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final font = ref.watch(appFontProvider);
    final locale = ref.watch(appLocaleProvider);
    final user = ref.watch(authStateChangesProvider).value;
    final profile = ref.watch(currentUserProfileProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(strings.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionHeader(title: strings.sectionAppearance),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text(strings.themeSystem),
                    icon: const Icon(Icons.brightness_auto_outlined),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text(strings.themeLight),
                    icon: const Icon(Icons.light_mode_outlined),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text(strings.themeDark),
                    icon: const Icon(Icons.dark_mode_outlined),
                  ),
                ],
                selected: {themeMode},
                onSelectionChanged: (s) =>
                    ref.read(themeModeProvider.notifier).update(s.first),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            strings.fontLabel,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Card(
            child: RadioGroup<AppFont>(
              groupValue: font,
              onChanged: (v) {
                if (v != null) ref.read(appFontProvider.notifier).update(v);
              },
              child: Column(
                children: [
                  for (final f in AppFont.values)
                    RadioListTile<AppFont>(
                      value: f,
                      title: Text(
                        f.label,
                        style: TextStyle(
                          fontFamily: f.fontFamily,
                          fontSize: 16,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          SectionHeader(title: strings.sectionLanguage),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SegmentedButton<Locale>(
                segments: [
                  ButtonSegment(
                    value: const Locale('en'),
                    label: Text(strings.languageEnglish),
                  ),
                  ButtonSegment(
                    value: const Locale('it'),
                    label: Text(strings.languageItalian),
                  ),
                ],
                selected: {Locale(locale.languageCode)},
                onSelectionChanged: (s) =>
                    ref.read(appLocaleProvider.notifier).update(s.first),
              ),
            ),
          ),
          const SizedBox(height: 28),
          SectionHeader(title: strings.sectionProfile),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (user?.email != null) ...[
                    Text(
                      strings.signedInAs,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      user!.email!,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (profile != null) ...[
                    Text(
                      '${strings.roleLabel}: ${strings.userRoleLabel(profile.role)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                  ],
                  OutlinedButton.icon(
                    onPressed: () => ref.read(authServiceProvider).signOut(),
                    icon: const Icon(Icons.logout),
                    label: Text(strings.signOutButton),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
