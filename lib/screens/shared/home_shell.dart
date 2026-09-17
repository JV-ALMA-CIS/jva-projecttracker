import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/screens/company_intelligence/company_intelligence_screen.dart';
import 'package:jva_projecttracker/screens/opportunities/opportunities_screen.dart';
import 'package:jva_projecttracker/screens/dashboard/dashboard_screen.dart';
import 'package:jva_projecttracker/screens/submissions/submissions_screen.dart';
import 'package:jva_projecttracker/screens/projects/projects_screen.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/breakpoints.dart';
import 'package:jva_projecttracker/widgets/app_sidebar.dart';
import 'package:jva_projecttracker/widgets/command_palette.dart';

class _NavDestinationData {
  const _NavDestinationData({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

const _screens = [
  DashboardScreen(),
  ProjectsScreen(),
  OpportunitiesScreen(),
  CompanyIntelligenceScreen(),
  SubmissionsScreen(),
];

Widget _fadeSwitcher(int index) {
  final safeIndex = index.clamp(0, _screens.length - 1);

  return AnimatedSwitcher(
    duration: const Duration(milliseconds: 200),
    switchInCurve: Curves.easeInOut,
    switchOutCurve: Curves.easeInOut,
    transitionBuilder: (child, animation) =>
        FadeTransition(opacity: animation, child: child),
    child: KeyedSubtree(key: ValueKey(safeIndex), child: _screens[safeIndex]),
  );
}

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  void _onDestinationSelected(int index) {
    ref.read(selectedTabIndexProvider.notifier).index = index;
  }

  Widget _dashboardIcon(int urgentCount) {
    if (urgentCount == 0) {
      return const Icon(Icons.dashboard_outlined);
    }

    return Badge(
      label: Text('$urgentCount'),
      child: const Icon(Icons.dashboard_outlined),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final index = ref.watch(selectedTabIndexProvider);
    final urgentCount = ref.watch(urgentAlertsProvider).length;

    final destinations = [
      _NavDestinationData(
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        label: strings.navDashboard,
      ),
      _NavDestinationData(
        icon: Icons.inventory_2_outlined,
        selectedIcon: Icons.inventory_2,
        label: strings.navProjects,
      ),
      _NavDestinationData(
        icon: Icons.travel_explore_outlined,
        selectedIcon: Icons.travel_explore,
        label: strings.navOpportunities,
      ),
      _NavDestinationData(
        icon: Icons.insights_outlined,
        selectedIcon: Icons.insights,
        label: strings.navCompanyIntelligence,
      ),
      _NavDestinationData(
        icon: Icons.send_outlined,
        selectedIcon: Icons.send,
        label: strings.submissionsSectionTitle,
      ),
    ];

    final width = MediaQuery.sizeOf(context).width;

    final Widget scaffold;

    if (width < AppBreakpoints.compact) {
      // 5 destinations + labels is tight on a small phone
      // (< AppBreakpoints.smallPhone, e.g. iPhone SE at ~375dp) — the
      // default NavigationBar sizing was designed around 3-5 items on a
      // ~390dp+ phone and visibly crowds/truncates below that. Dropping to
      // `selectedLabel` (label only under the active item) recovers enough
      // horizontal room for every icon to sit comfortably instead of
      // squeezing all five icon+label pairs into the same row.
      final isSmallPhone = width < AppBreakpoints.smallPhone;
      scaffold = Scaffold(
        body: SafeArea(child: _fadeSwitcher(index)),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: _onDestinationSelected,
          labelBehavior: isSmallPhone
              ? NavigationDestinationLabelBehavior.onlyShowSelected
              : NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            for (final (i, destination) in destinations.indexed)
              NavigationDestination(
                icon: i == 0
                    ? _dashboardIcon(urgentCount)
                    : Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: destination.label,
              ),
          ],
        ),
      );
    } else {
      final extended = width >= AppBreakpoints.medium;

      scaffold = Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              AppSidebar(
                destinations: [
                  for (final destination in destinations)
                    SidebarDestination(
                      icon: destination.icon,
                      selectedIcon: destination.selectedIcon,
                      label: destination.label,
                    ),
                ],
                selectedIndex: index,
                onDestinationSelected: _onDestinationSelected,
                extended: extended,
                badgeCounts: {0: urgentCount},
              ),
              const VerticalDivider(width: 1),
              Expanded(child: _fadeSwitcher(index)),
            ],
          ),
        ),
      );
    }

    // Global Ctrl+K/Cmd+K — works regardless of which tab is active
    // or what has focus, since this wraps the entire shell rather
    // than one screen.
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
            showCommandPalette(context),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
            showCommandPalette(context),
      },
      child: Focus(autofocus: true, child: scaffold),
    );
  }
}
