import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/user_profile.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/widgets/app_sidebar.dart';
import 'package:jva_projecttracker/widgets/command_palette_button.dart';
import 'package:jva_projecttracker/widgets/notification_bell_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _destinations = [
  SidebarDestination(
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
    label: 'Dashboard',
  ),
  SidebarDestination(
    icon: Icons.travel_explore_outlined,
    selectedIcon: Icons.travel_explore,
    label: 'Opportunities',
  ),
];

Future<void> _pumpSidebar(
  WidgetTester tester, {
  required bool extended,
  UserProfile? userProfile,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currentUserProfileProvider.overrideWith(
          (ref) => Stream.value(userProfile),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: AppSidebar(
            destinations: _destinations,
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            extended: extended,
            badgeCounts: const {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final profile = UserProfile(
    uid: 'u1',
    email: 'jane@jvalmacis.com',
    role: UserRole.user,
    createdAt: DateTime(2024, 1, 1),
  );

  testWidgets('renders the global Search action exactly once', (tester) async {
    await _pumpSidebar(tester, extended: true, userProfile: profile);

    expect(find.byType(CommandPaletteButton), findsOneWidget);
  });

  testWidgets('renders the global Notifications action exactly once', (
    tester,
  ) async {
    await _pumpSidebar(tester, extended: true, userProfile: profile);

    expect(find.byType(NotificationBellButton), findsOneWidget);
  });

  testWidgets('renders Settings in the footer', (tester) async {
    await _pumpSidebar(tester, extended: true, userProfile: profile);

    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('Profile renders below Settings when a user is signed in', (
    tester,
  ) async {
    await _pumpSidebar(tester, extended: true, userProfile: profile);

    final settingsTop = tester.getTopLeft(find.text('Settings')).dy;
    final profileTop = tester.getTopLeft(find.text(profile.email)).dy;

    expect(find.text(profile.email), findsOneWidget);
    expect(
      profileTop,
      greaterThan(settingsTop),
      reason: 'Profile should be positioned below Settings in the footer',
    );
  });

  testWidgets('does not render duplicate global action instances', (
    tester,
  ) async {
    await _pumpSidebar(tester, extended: true, userProfile: profile);

    expect(find.byType(CommandPaletteButton), findsOneWidget);
    expect(find.byType(NotificationBellButton), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });

  testWidgets(
    'extended state shows destination labels and remains free of overflow',
    (tester) async {
      await _pumpSidebar(tester, extended: true, userProfile: profile);

      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Opportunities'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'collapsed state hides destination labels but keeps global actions and remains free of overflow',
    (tester) async {
      await _pumpSidebar(tester, extended: false, userProfile: profile);

      expect(find.text('Dashboard'), findsNothing);
      expect(find.text('Opportunities'), findsNothing);
      expect(find.byType(CommandPaletteButton), findsOneWidget);
      expect(find.byType(NotificationBellButton), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('renders without a signed-in user without throwing', (
    tester,
  ) async {
    await _pumpSidebar(tester, extended: true, userProfile: null);

    expect(find.byType(CommandPaletteButton), findsOneWidget);
    expect(find.byType(NotificationBellButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
