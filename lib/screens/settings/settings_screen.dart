import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_font.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
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
          SectionHeader(
            title: strings.sectionAppearance,
            accentColor: AppStatusColors.neutral,
          ),
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
          SectionHeader(
            title: strings.sectionLanguage,
            accentColor: AppStatusColors.neutral,
          ),
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
          SectionHeader(
            title: strings.sectionNotifications,
            accentColor: AppStatusColors.info,
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.notificationsExplainer,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  if (user != null) _TestNotificationButton(uid: user.uid),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          SectionHeader(
            title: strings.sectionProfile,
            accentColor: AppStatusColors.info,
          ),
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
                    onPressed: () async {
                      // Must run before signOut(): once signed out, the
                      // fcmTokens subcollection this device's token lives
                      // under is no longer readable/writable by this client
                      // (firestore.rules scopes it to the owning uid). See
                      // FcmTokenService.deleteCurrentToken's doc comment for
                      // why leaving it behind matters on a shared device.
                      if (user != null) {
                        await ref
                            .read(fcmTokenServiceProvider)
                            .deleteCurrentToken(user.uid);
                      }
                      await ref.read(authServiceProvider).signOut();
                    },
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

/// Registers this device for push (asking permission if needed) and sends a
/// test notification to every device the signed-in user has registered.
class _TestNotificationButton extends ConsumerStatefulWidget {
  const _TestNotificationButton({required this.uid});

  final String uid;

  @override
  ConsumerState<_TestNotificationButton> createState() =>
      _TestNotificationButtonState();
}

class _TestNotificationButtonState
    extends ConsumerState<_TestNotificationButton> {
  bool _sending = false;

  Future<void> _send() async {
    final strings = ref.read(appStringsProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    String message;
    try {
      final outcome = await ref
          .read(fcmTokenServiceProvider)
          .sendTestNotification(widget.uid);
      message = strings.testNotificationResult(outcome);
    } catch (e) {
      developer.log(
        'sendTestNotification failed',
        name: 'SettingsScreen',
        error: e,
      );
      message = strings.testNotificationError;
    }
    if (!mounted) return;
    setState(() => _sending = false);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    return FilledButton.tonalIcon(
      onPressed: _sending ? null : _send,
      icon: _sending
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.notifications_active_outlined),
      label: Text(strings.sendTestNotificationButton),
    );
  }
}
