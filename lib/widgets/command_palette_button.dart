import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/widgets/command_palette.dart';

/// Touch/mouse entry point for [showCommandPalette] — same shape as
/// [NotificationBellButton]/[SettingsButton], added alongside them to every
/// primary screen's [AppBar]. The `Ctrl+K`/`Cmd+K` shortcut (wired once in
/// `HomeShell`) works everywhere already; this is just the discoverable
/// on-screen affordance for it.
class CommandPaletteButton extends ConsumerWidget {
  const CommandPaletteButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    return IconButton(
      onPressed: () => showCommandPalette(context),
      icon: const Icon(Icons.search),
      tooltip: strings.commandPaletteTooltip,
    );
  }
}
