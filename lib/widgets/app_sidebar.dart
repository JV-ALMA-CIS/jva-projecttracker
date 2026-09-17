import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/screens/settings/settings_screen.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_page_route.dart';
import 'package:jva_projecttracker/theme/app_scale.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/command_palette_button.dart';
import 'package:jva_projecttracker/widgets/notification_bell_button.dart';

class SidebarDestination {
  const SidebarDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// The desktop/tablet persistent navigation sidebar — replaces the bare
/// Material [NavigationRail] with a branded shell (logo + product name,
/// hover/active/pressed states per item, signed-in user footer) while
/// keeping exactly the same destinations/selection model as before: still
/// driven by [selectedTabIndexProvider], still just an index selector, no
/// new navigation architecture. [extended] mirrors what `NavigationRail`'s
/// own `extended` flag did — collapse to icon-only under the medium
/// breakpoint, matching Material's own persistent-vs-collapsed convention
/// rather than inventing a new one.
class AppSidebar extends ConsumerWidget {
  const AppSidebar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.extended,
    required this.badgeCounts,
  });

  final List<SidebarDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool extended;

  /// Index -> badge count (0 renders no badge). Currently only Dashboard
  /// carries a live count (urgent alerts), matching `HomeShell`'s prior
  /// bare-rail behavior — not a new signal, just re-presented.
  final Map<int, int> badgeCounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userProfile = ref.watch(currentUserProfileProvider).value;

    // Continuous rather than a hard 88/240 toggle: within each mode the
    // rail's own width still scales with how much room the window actually
    // has, so a 14" laptop window and a spacious 16"+ desktop — both
    // "extended" — get a rail sized for their own width rather than an
    // identical fixed one. Collapsed (icon-only) mode gets the same
    // treatment across its own, much narrower, band.
    final windowWidth = MediaQuery.sizeOf(context).width;
    final width = extended
        ? AppScale.lerp(windowWidth, 220, 272)
        : AppScale.lerp(windowWidth, 72, 96);

    return Container(
      width: width,
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              mainAxisAlignment: extended
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(AppRadii.input),
                  ),
                  child: Text(
                    'JV',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (extended) ...[
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'JV ALMA CIS',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Intelligence Platform',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Global actions — the one place Search/Notifications live for the
          // whole shell. Every main module used to declare its own AppBar
          // with copies of these two buttons (and Submissions had neither),
          // which meant the same action existed in up to five places with
          // inconsistent coverage. Living here once means every screen
          // reachable through the persistent shell gets them for free.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: extended
                ? const Row(
                    children: [
                      CommandPaletteButton(),
                      NotificationBellButton(),
                    ],
                  )
                : const Column(
                    children: [
                      CommandPaletteButton(),
                      NotificationBellButton(),
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              children: [
                for (final (i, destination) in destinations.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: _SidebarItem(
                      destination: destination,
                      selected: i == selectedIndex,
                      extended: extended,
                      badgeCount: badgeCounts[i] ?? 0,
                      onTap: () => onDestinationSelected(i),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Builder(
              builder: (context) {
                final strings = ref.watch(appStringsProvider);
                return InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.chip),
                  onTap: () => pushSlideFade(context, const SettingsScreen()),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: extended ? AppSpacing.md : AppSpacing.sm,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      mainAxisAlignment: extended
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.settings_outlined,
                          size: 22,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        if (extended) ...[
                          const SizedBox(width: AppSpacing.md),
                          Text(
                            strings.settingsTitle,
                            style: theme.textTheme.labelLarge,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (userProfile != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Row(
                mainAxisAlignment: extended
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      userProfile.email.isNotEmpty
                          ? userProfile.email[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (extended) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        userProfile.email,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            )
          else
            const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.extended,
    required this.badgeCount,
    required this.onTap,
  });

  final SidebarDestination destination;
  final bool selected;
  final bool extended;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = widget.selected;
    final background = selected
        ? theme.colorScheme.primaryContainer
        : _hovering
        ? theme.colorScheme.surfaceContainerHighest
        : Colors.transparent;
    final foreground = selected
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurfaceVariant;

    final icon = Icon(
      selected ? widget.destination.selectedIcon : widget.destination.icon,
      color: foreground,
      size: 22,
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadii.chip),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.chip),
          onTap: widget.onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.extended ? AppSpacing.md : AppSpacing.sm,
              vertical: AppSpacing.md,
            ),
            child: Row(
              mainAxisAlignment: widget.extended
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                widget.badgeCount > 0
                    ? Badge(label: Text('${widget.badgeCount}'), child: icon)
                    : icon,
                if (widget.extended) ...[
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      widget.destination.label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: foreground,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
