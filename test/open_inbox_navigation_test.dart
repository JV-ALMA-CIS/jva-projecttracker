import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/services/core/navigation_providers.dart';

void main() {
  test(
    'openOpportunityInbox switches to Opportunities and requests the Inbox tab',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      openOpportunityInbox(container);

      expect(container.read(selectedTabIndexProvider), kOpportunitiesTabIndex);
      expect(
        container.read(requestedOpportunitiesTabProvider),
        kOpportunitiesInboxTab,
      );

      container.read(requestedOpportunitiesTabProvider.notifier).clear();
      expect(container.read(requestedOpportunitiesTabProvider), isNull);
    },
  );
}
