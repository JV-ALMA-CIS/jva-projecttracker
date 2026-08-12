import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/project.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/widgets/adaptive_list_grid.dart';
import 'package:jva_projecttracker/widgets/project_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

Project _project({
  required String name,
  bool withSourceOpportunity = false,
  bool withExperience = false,
}) {
  final now = DateTime(2024, 1, 1);
  return Project(
    id: name,
    name: name,
    description: '',
    client: 'A Very Long Client Name That Wraps',
    status: ProjectStatus.running,
    category: ProjectCategory.waterSanitation,
    location: 'Nairobi, Kenya',
    contractValueAmount: 1250000,
    contractValueCurrency: 'USD',
    contractorRole: ContractorRole.mainContractor,
    clientType: ClientType.government,
    sourceOpportunityId: withSourceOpportunity ? 'opp-1' : null,
    experienceId: withExperience ? 'exp-1' : null,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  testWidgets(
    'ProjectCard with every optional chip does not overflow in a narrow grid tile',
    (tester) async {
      // Reproduces the reported "RenderFlex overflowed" bug: a project with
      // a long name/client, a contract value, and both optional chips
      // (source opportunity + linked experience) is the maximum-content
      // case — 5 meta chips plus a wrapping title/subtitle — rendered at
      // the narrowest width AdaptiveListGrid will still put into its
      // multi-column grid mode (just over minTileWidth), which is exactly
      // where a fixed-height grid cell is most likely to be shorter than
      // the card's natural content height.
      final project = _project(
        name: 'Baringo Agricultural Capacity Building and Irrigation Project',
        withSourceOpportunity: true,
        withExperience: true,
      );

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 700, // 2 columns at the default 320 minTileWidth
                height: 400,
                child: AdaptiveListGrid<Project>(
                  items: [project],
                  tileHeight: 172,
                  itemBuilder: (context, p) => ProjectCard(project: p),
                ),
              ),
            ),
          ),
        ),
      );

      // Let FadeSlideIn's staggered entrance timers fire.
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ProjectCard with no optional chips renders without overflow', (
    tester,
  ) async {
    final project = _project(name: 'Short Name');

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 700,
              height: 400,
              child: AdaptiveListGrid<Project>(
                items: [project],
                tileHeight: 172,
                itemBuilder: (context, p) => ProjectCard(project: p),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
