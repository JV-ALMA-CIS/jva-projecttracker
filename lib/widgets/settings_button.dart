import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/screens/settings/settings_screen.dart';
import 'package:jva_projecttracker/theme/app_page_route.dart';

/// Profile/settings entry point added to each primary screen's [AppBar].
class SettingsButton extends ConsumerWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    return IconButton(
      onPressed: () => pushSlideFade(context, const SettingsScreen()),
      icon: const Icon(Icons.person_outline),
      tooltip: strings.settingsTooltip,
    );
  }
}
