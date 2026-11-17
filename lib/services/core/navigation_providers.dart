import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which `HomeShell` tab is selected — lifted out of `HomeShell`'s local
/// state so global chrome (the command palette's "Go to" entries) can
/// switch tabs the same way tapping the nav bar/rail does, instead of
/// pushing a duplicate screen onto the Navigator. Same shape as
/// [ThemeModeController]/[AppLocaleController].
class SelectedTabIndexController extends Notifier<int> {
  @override
  int build() => 0;

  set index(int value) => state = value;
}

final selectedTabIndexProvider =
    NotifierProvider<SelectedTabIndexController, int>(
      SelectedTabIndexController.new,
    );

/// HomeShell tab index of Opportunities.
const kOpportunitiesTabIndex = 2;

/// Inner tab index of the Inbox on the Opportunities screen.
const kOpportunitiesInboxTab = 1;

/// A one-off request for the Opportunities screen to switch to an inner
/// tab (e.g. tapping the weekly-summary push opens the Inbox). The screen
/// consumes it and clears it.
class RequestedOpportunitiesTabController extends Notifier<int?> {
  @override
  int? build() => null;

  void request(int tab) => state = tab;

  void clear() => state = null;
}

final requestedOpportunitiesTabProvider =
    NotifierProvider<RequestedOpportunitiesTabController, int?>(
      RequestedOpportunitiesTabController.new,
    );

/// Shows the Opportunity Inbox: switches to the Opportunities tab and asks
/// it to open its Inbox tab.
void openOpportunityInbox(ProviderContainer container) {
  container.read(selectedTabIndexProvider.notifier).index =
      kOpportunitiesTabIndex;
  container
      .read(requestedOpportunitiesTabProvider.notifier)
      .request(kOpportunitiesInboxTab);
}
