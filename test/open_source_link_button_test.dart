import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/widgets/open_source_link_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _strings = AppStrings(Locale('en'));

Future<void> _pumpButton(
  WidgetTester tester, {
  bool? verified,
  Future<void> Function()? onMarkVerified,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        home: Scaffold(
          body: OpenSourceLinkButton(
            rawUrl: 'https://example.com/tender/1',
            label: 'Open tender',
            verified: verified,
            onMarkVerified: onMarkVerified,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'tapping an unverified link shows the confirmation dialog instead of opening immediately',
    (tester) async {
      await _pumpButton(tester, verified: false);

      await tester.tap(find.text('Open tender'));
      await tester.pumpAndSettle();

      expect(find.text(_strings.unverifiedLinkDialogTitle), findsOneWidget);
      expect(find.text(_strings.unverifiedLinkDialogMessage), findsOneWidget);
      expect(find.text(_strings.openAnywayButton), findsOneWidget);
      expect(find.text(_strings.cancelButton), findsOneWidget);
    },
  );

  testWidgets('cancelling the confirmation dialog dismisses it without error', (
    tester,
  ) async {
    await _pumpButton(tester, verified: false);

    await tester.tap(find.text('Open tender'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_strings.cancelButton));
    await tester.pumpAndSettle();

    expect(find.text(_strings.unverifiedLinkDialogTitle), findsNothing);
  });

  testWidgets('confirming "Open anyway" dismisses the dialog', (tester) async {
    await _pumpButton(tester, verified: false);

    await tester.tap(find.text('Open tender'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_strings.openAnywayButton));
    await tester.pumpAndSettle();

    expect(find.text(_strings.unverifiedLinkDialogTitle), findsNothing);
  });

  testWidgets(
    'a verified link never shows the confirmation dialog or the unverified warning badge',
    (tester) async {
      await _pumpButton(tester, verified: true);

      await tester.tap(find.text('Open tender'));
      await tester.pumpAndSettle();

      expect(find.text(_strings.unverifiedLinkDialogTitle), findsNothing);
      expect(find.byIcon(Icons.warning_amber_outlined), findsNothing);
    },
  );

  testWidgets(
    'a caller that does not track verification (verified: null) never shows the dialog',
    (tester) async {
      await _pumpButton(tester);

      await tester.tap(find.text('Open tender'));
      await tester.pumpAndSettle();

      expect(find.text(_strings.unverifiedLinkDialogTitle), findsNothing);
      expect(find.byIcon(Icons.warning_amber_outlined), findsNothing);
    },
  );

  testWidgets(
    'an unverified link still shows the warning badge and mark-verified action',
    (tester) async {
      var marked = false;
      await _pumpButton(
        tester,
        verified: false,
        onMarkVerified: () async {
          marked = true;
        },
      );

      expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
      expect(find.text(_strings.markLinkVerifiedButton), findsOneWidget);

      await tester.tap(find.text(_strings.markLinkVerifiedButton));
      await tester.pumpAndSettle();

      expect(marked, isTrue);
    },
  );
}
