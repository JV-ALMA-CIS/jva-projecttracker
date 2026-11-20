import 'dart:developer' as developer;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/app_version.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/device_registration.dart';
import 'package:jva_projecttracker/models/user_profile.dart';
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
                  if (user != null) ...[
                    _TestNotificationButton(uid: user.uid),
                    const SizedBox(height: 16),
                    const _MyDevicesList(),
                  ],
                ],
              ),
            ),
          ),
          if (profile?.role == UserRole.admin) ...[
            const SizedBox(height: 12),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: _TeamReachability(),
              ),
            ),
          ],
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
                  if (user != null) ...[
                    const _DisplayNameField(),
                    const SizedBox(height: 16),
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
          const SizedBox(height: 16),
          Center(
            child: Text(
              strings.appVersionLabel(kAppVersion),
              style: Theme.of(context).textTheme.bodySmall,
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

/// The signed-in person's registered devices, so they can see at a glance
/// whether their desk computer and phone will actually get alerts.
class _MyDevicesList extends ConsumerWidget {
  const _MyDevicesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    final devices = ref.watch(myDevicesProvider);
    final currentToken = ref.watch(fcmTokenServiceProvider).currentToken;
    final DateTime now = DateTime.now();

    final List<DeviceRegistration>? list = devices.value;
    if (list == null) {
      if (devices.hasError) return const SizedBox.shrink();
      return const LinearProgressIndicator();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(strings.myDevicesTitle, style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        if (list.isEmpty)
          Text(
            strings.noDevicesYet,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        for (final DeviceRegistration d in list)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(
              d.isWeb ? Icons.computer_outlined : Icons.smartphone_outlined,
            ),
            title: Text(
              d.token == currentToken
                  ? '${deviceLabel(d.platform, d.os)} · '
                        '${strings.thisDeviceLabel}'
                  : deviceLabel(d.platform, d.os),
            ),
            subtitle: Text(
              [
                if (d.updatedAt != null)
                  strings.deviceRegisteredLine(
                    strings.relativeWhen(d.updatedAt!, now),
                  ),
                d.lastSentAt == null
                    ? strings.deviceNoAlertYet
                    : strings.deviceLastAlertLine(
                        strings.relativeWhen(d.lastSentAt!, now),
                      ),
              ].join(' · '),
            ),
          ),
      ],
    );
  }
}

/// Admin-only: every team sign-in account and how many devices it gets
/// alerts on (`notificationReachability` Cloud Function), people with none
/// first — so an admin can chase whoever would miss a tender.
class _TeamReachability extends ConsumerStatefulWidget {
  const _TeamReachability();

  @override
  ConsumerState<_TeamReachability> createState() => _TeamReachabilityState();
}

class _TeamReachabilityState extends ConsumerState<_TeamReachability> {
  bool _loading = false;
  List<Map<String, dynamic>>? _people;
  String? _error;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('notificationReachability')
          .call<Map<String, dynamic>>();
      final List<Object?> raw =
          (result.data['people'] as List<Object?>?) ?? const [];
      if (!mounted) return;
      setState(() {
        _people = raw
            .whereType<Map<Object?, Object?>>()
            .map(Map<String, dynamic>.from)
            .toList();
      });
    } catch (e) {
      developer.log(
        'notificationReachability failed',
        name: 'Settings',
        error: e,
      );
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    final DateTime now = DateTime.now();
    final List<Map<String, dynamic>>? people = _people;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(strings.teamReachabilityTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          strings.teamReachabilityExplainer,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _loading ? null : _load,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.groups_outlined),
          label: Text(strings.checkTeamReachabilityButton),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            strings.errorPrefix(_error!),
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
        if (people != null)
          for (final Map<String, dynamic> p in people)
            _PersonReachabilityTile(person: p, now: now),
      ],
    );
  }
}

class _PersonReachabilityTile extends ConsumerWidget {
  const _PersonReachabilityTile({required this.person, required this.now});

  final Map<String, dynamic> person;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    final List<Map<String, dynamic>> devices =
        ((person['devices'] as List<Object?>?) ?? const [])
            .whereType<Map<Object?, Object?>>()
            .map(Map<String, dynamic>.from)
            .toList();
    final String name = (person['name'] as String?) ?? '';
    final String email = (person['email'] as String?) ?? '';
    final DateTime? lastSignIn = DateTime.tryParse(
      (person['lastSignInAt'] as String?) ?? '',
    );
    final bool reachable = devices.isNotEmpty;

    final String deviceSummary = reachable
        ? '${strings.personDeviceCount(devices.length)}: '
              '${devices.map((d) => deviceLabel('${d['platform']}', '${d['os']}')).join(', ')}'
        : strings.personNoDevices;
    final String signIn = lastSignIn == null
        ? strings.neverSignedIn
        : strings.lastSignInLine(strings.relativeWhen(lastSignIn, now));

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(
        reachable
            ? Icons.notifications_active_outlined
            : Icons.notifications_off_outlined,
        color: reachable ? AppStatusColors.success : theme.colorScheme.error,
      ),
      title: Text(name.isNotEmpty ? '$name · $email' : email),
      subtitle: Text('$deviceSummary · $signIn'),
    );
  }
}

/// The name colleagues see when this person shares an opportunity. Stored
/// on the login profile (Firebase Auth display name), which the
/// `shareOpportunityWithTeam` function reads from the sign-in token.
class _DisplayNameField extends ConsumerStatefulWidget {
  const _DisplayNameField();

  @override
  ConsumerState<_DisplayNameField> createState() => _DisplayNameFieldState();
}

class _DisplayNameFieldState extends ConsumerState<_DisplayNameField> {
  late final TextEditingController _controller = TextEditingController(
    text: FirebaseAuth.instance.currentUser?.displayName ?? '',
  );
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final strings = ref.read(appStringsProvider);
    final messenger = ScaffoldMessenger.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      await user.updateDisplayName(_controller.text.trim());
      // Refresh the sign-in token so the next share carries the new name.
      await user.getIdToken(true);
      messenger.showSnackBar(SnackBar(content: Text(strings.nameSavedMessage)));
    } catch (e) {
      developer.log('Saving display name failed', name: 'Settings', error: e);
      messenger.showSnackBar(SnackBar(content: Text(strings.errorPrefix(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: strings.yourNameLabel,
              helperText: strings.yourNameHelper,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: FilledButton.tonal(
            onPressed: _saving ? null : _save,
            child: Text(strings.saveButtonShort),
          ),
        ),
      ],
    );
  }
}
