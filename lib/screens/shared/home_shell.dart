import 'package:flutter/material.dart';
import 'package:jva_projecttracker/screens/applications/applications_screen.dart';
import 'package:jva_projecttracker/screens/contracts/contracts_screen.dart';
import 'package:jva_projecttracker/screens/dashboard/dashboard_screen.dart';
import 'package:jva_projecttracker/screens/projects/projects_screen.dart';
import 'package:jva_projecttracker/theme/breakpoints.dart';

class _NavDestinationData {
  const _NavDestinationData({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

const _destinations = [
  _NavDestinationData(icon: Icons.dashboard_outlined, label: 'Dashboard'),
  _NavDestinationData(icon: Icons.work_outline, label: 'Projects'),
  _NavDestinationData(icon: Icons.apps_outlined, label: 'Applications'),
  _NavDestinationData(icon: Icons.travel_explore_outlined, label: 'Contracts'),
];

const _screens = [
  DashboardScreen(),
  ProjectsScreen(),
  ApplicationsScreen(),
  ContractsScreen(),
];

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _onDestinationSelected(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    if (width < AppBreakpoints.compact) {
      return Scaffold(
        body: SafeArea(child: _screens[_index]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _onDestinationSelected,
          destinations: [
            for (final d in _destinations)
              NavigationDestination(icon: Icon(d.icon), label: d.label),
          ],
        ),
      );
    }

    final extended = width >= AppBreakpoints.medium;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: _onDestinationSelected,
              extended: extended,
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _screens[_index]),
          ],
        ),
      ),
    );
  }
}
