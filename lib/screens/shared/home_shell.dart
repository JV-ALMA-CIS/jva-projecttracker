import 'package:flutter/material.dart';
import 'package:jva_projecttracker/screens/applications/applications_screen.dart';
import 'package:jva_projecttracker/screens/contracts/contracts_screen.dart';
import 'package:jva_projecttracker/screens/dashboard/dashboard_screen.dart';
import 'package:jva_projecttracker/screens/projects/projects_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _screens = [
    DashboardScreen(),
    ProjectsScreen(),
    ApplicationsScreen(),
    ContractsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _screens[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.work_outline),
            label: 'Projects',
          ),
          NavigationDestination(
            icon: Icon(Icons.apps_outlined),
            label: 'Applications',
          ),
          NavigationDestination(
            icon: Icon(Icons.travel_explore_outlined),
            label: 'Contracts',
          ),
        ],
      ),
    );
  }
}
