import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/services/core/settings_providers.dart';
import 'package:jva_projecttracker/services/opportunity_filters.dart';

/// The Opportunity Inbox is pre-sorted so nobody has to filter by hand:
/// one tab per kind (Tenders / Grants & Calls / Programmes), and — for
/// tenders — one chip per business unit. Each person's last tab and chip
/// are remembered on their device, so a manager who only reads grants
/// lands straight on grants next time.

/// The score the Inbox ranks by: the full Match Analysis score when there
/// is one, otherwise the discovery fit score.
int inboxScore(Opportunity o) => o.overallMatchScore ?? o.fitScorePercent;

/// Still worth triaging: no deadline, or a deadline that hasn't passed.
bool isStillOpen(Opportunity o, DateTime now) =>
    o.deadline == null || o.deadline!.isAfter(now);

/// Inbox order: best match first, then soonest deadline (no deadline last),
/// then newest.
int compareForInbox(Opportunity a, Opportunity b) {
  final byScore = inboxScore(b).compareTo(inboxScore(a));
  if (byScore != 0) return byScore;
  final da = a.deadline;
  final db = b.deadline;
  if (da != null && db != null) {
    final byDeadline = da.compareTo(db);
    if (byDeadline != 0) return byDeadline;
  } else if (da != null) {
    return -1;
  } else if (db != null) {
    return 1;
  }
  return b.discoveredAt.compareTo(a.discoveredAt);
}

int _eligibilityRank(Opportunity o) => switch (o.eligibility) {
  GrantEligibility.notEligible => 2,
  GrantEligibility.needsPartner => 1,
  _ => 0,
};

/// Grants & programmes order (Synnefa-style "funding open now"): ones JVA
/// can apply for first, then ones needing a partner, not-eligible last;
/// within each, soonest deadline first (rolling last), then best match.
/// Funder-watchlist calls have no match score, so ranking grants by score
/// (as tenders are) would bury them.
int compareGrantsForInbox(Opportunity a, Opportunity b) {
  final byEligibility = _eligibilityRank(a).compareTo(_eligibilityRank(b));
  if (byEligibility != 0) return byEligibility;
  final da = a.deadline;
  final db = b.deadline;
  if (da != null && db != null) {
    final byDeadline = da.compareTo(db);
    if (byDeadline != 0) return byDeadline;
  } else if (da != null) {
    return -1;
  } else if (db != null) {
    return 1;
  }
  final byScore = inboxScore(b).compareTo(inboxScore(a));
  if (byScore != 0) return byScore;
  return b.discoveredAt.compareTo(a.discoveredAt);
}

/// How many Inbox items there are of each kind (for the tab labels).
Map<OpportunityKind, int> inboxKindCounts(List<Opportunity> inbox) {
  final counts = {for (final k in OpportunityKind.values) k: 0};
  for (final o in inbox) {
    counts[o.kind] = counts[o.kind]! + 1;
  }
  return counts;
}

/// The Inbox items for one tab and (optionally) one business unit.
List<Opportunity> inboxSlice(
  List<Opportunity> inbox, {
  required OpportunityKind kind,
  OpportunityBuFilter businessUnit = const OpportunityBuFilter.all(),
}) {
  final List<Opportunity> slice = inbox
      .where((o) => o.kind == kind && matchesBuFilter(o, businessUnit))
      .toList();
  if (kind != OpportunityKind.tender) slice.sort(compareGrantsForInbox);
  return slice;
}

/// One person's remembered Inbox selection.
class InboxView {
  const InboxView({required this.kind, this.businessUnitId});

  final OpportunityKind kind;

  /// Null means "All business units".
  final String? businessUnitId;
}

class InboxViewController extends Notifier<InboxView> {
  static const _kindKey = 'inbox.kind';
  static const _businessUnitKey = 'inbox.businessUnitId';

  @override
  InboxView build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return InboxView(
      kind: OpportunityKindX.fromString(prefs.getString(_kindKey)),
      businessUnitId: prefs.getString(_businessUnitKey),
    );
  }

  void setKind(OpportunityKind kind) {
    state = InboxView(kind: kind, businessUnitId: state.businessUnitId);
    ref.read(sharedPreferencesProvider).setString(_kindKey, kind.name);
  }

  void setBusinessUnit(String? businessUnitId) {
    state = InboxView(kind: state.kind, businessUnitId: businessUnitId);
    final prefs = ref.read(sharedPreferencesProvider);
    if (businessUnitId == null) {
      prefs.remove(_businessUnitKey);
    } else {
      prefs.setString(_businessUnitKey, businessUnitId);
    }
  }
}

final inboxViewProvider = NotifierProvider<InboxViewController, InboxView>(
  InboxViewController.new,
);
