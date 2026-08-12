import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/tender_source.dart';

/// Business Unit selector state for the Opportunities Pipeline tab —
/// separate from an ordinary nullable business-unit id string so "All" and
/// "Unassigned" are both explicit, distinguishable selections rather than
/// null meaning two different things.
enum OpportunityBuSelection { all, unassigned, specific }

class OpportunityBuFilter {
  const OpportunityBuFilter.all()
    : selection = OpportunityBuSelection.all,
      businessUnitId = null;
  const OpportunityBuFilter.unassigned()
    : selection = OpportunityBuSelection.unassigned,
      businessUnitId = null;
  const OpportunityBuFilter.specific(String id)
    : selection = OpportunityBuSelection.specific,
      businessUnitId = id;

  final OpportunityBuSelection selection;
  final String? businessUnitId;
}

/// True when [opportunity] belongs to the business unit selected by
/// [filter]. `all` never constrains; `unassigned` matches an empty
/// `businessUnitIds` list (never invents a BU); `specific` matches the
/// existing `businessUnitIds.contains` convention already used by
/// `businessUnitOpportunitiesProvider`.
bool matchesBuFilter(Opportunity opportunity, OpportunityBuFilter filter) {
  switch (filter.selection) {
    case OpportunityBuSelection.all:
      return true;
    case OpportunityBuSelection.unassigned:
      return opportunity.businessUnitIds.isEmpty;
    case OpportunityBuSelection.specific:
      return opportunity.businessUnitIds.contains(filter.businessUnitId);
  }
}

/// Value bands over `Opportunity.estimatedBudget` — the one numeric value
/// field the model has (no separate contractValue/amount field exists on
/// Opportunity; that field lives on Project post-award instead).
enum ValueBand { any, under50k, from50kTo250k, from250kTo1m, over1m, unknown }

/// True when [amount] (an opportunity's `estimatedBudget`) falls in [band].
/// `any` always matches, including a null amount. `unknown` matches only a
/// null amount. Every other band requires a non-null amount in range — a
/// missing value never silently matches a specific band, per the brief's
/// "missing value != match a specific band" rule.
bool matchesValueBand(double? amount, ValueBand band) {
  switch (band) {
    case ValueBand.any:
      return true;
    case ValueBand.unknown:
      return amount == null;
    case ValueBand.under50k:
      return amount != null && amount < 50000;
    case ValueBand.from50kTo250k:
      return amount != null && amount >= 50000 && amount < 250000;
    case ValueBand.from250kTo1m:
      return amount != null && amount >= 250000 && amount < 1000000;
    case ValueBand.over1m:
      return amount != null && amount >= 1000000;
  }
}

/// Deadline windows over `Opportunity.deadline`, measured against [now]
/// (injected for testability). `any` always matches. `noDeadline` matches
/// only a null deadline. Every other window requires a non-null deadline —
/// same "missing != match" rule as [matchesValueBand].
enum DeadlineWindow {
  any,
  overdue,
  within7Days,
  within14Days,
  within30Days,
  noDeadline,
}

bool matchesDeadlineWindow(
  DateTime? deadline,
  DeadlineWindow window, {
  required DateTime now,
}) {
  switch (window) {
    case DeadlineWindow.any:
      return true;
    case DeadlineWindow.noDeadline:
      return deadline == null;
    case DeadlineWindow.overdue:
      return deadline != null && deadline.isBefore(now);
    case DeadlineWindow.within7Days:
      return deadline != null &&
          !deadline.isBefore(now) &&
          deadline.isBefore(now.add(const Duration(days: 7)));
    case DeadlineWindow.within14Days:
      return deadline != null &&
          !deadline.isBefore(now) &&
          deadline.isBefore(now.add(const Duration(days: 14)));
    case DeadlineWindow.within30Days:
      return deadline != null &&
          !deadline.isBefore(now) &&
          deadline.isBefore(now.add(const Duration(days: 30)));
  }
}

/// Fit-score thresholds over `Opportunity.fitScorePercent` — always present
/// (defaults to 0, never null), so unlike value/deadline there is no
/// "missing" case to special-case here; every opportunity has some score.
enum FitScoreThreshold { any, at50, at70, at85 }

bool matchesFitScoreThreshold(
  int fitScorePercent,
  FitScoreThreshold threshold,
) {
  switch (threshold) {
    case FitScoreThreshold.any:
      return true;
    case FitScoreThreshold.at50:
      return fitScorePercent >= 50;
    case FitScoreThreshold.at70:
      return fitScorePercent >= 70;
    case FitScoreThreshold.at85:
      return fitScorePercent >= 85;
  }
}

/// The funding/buyer-type facet — a best-effort classification built
/// entirely from fields the model already has (`tenderSourceCategory` for
/// opportunities discovered via a Tender Source connector — Milestone
/// 3.8a — falling back to the older `discoverySourceType` for
/// opportunities predating that milestone). Neither field is ever guessed
/// from free text; an opportunity with neither set is `unknown`, never
/// defaulted to `other`.
enum BuyerTypeFacet {
  any,
  government,
  developmentPartner,
  unAgency,
  ngo,
  privateSector,
  unknown,
}

/// Classifies one opportunity into a [BuyerTypeFacet] for both filtering
/// and display — `tenderSourceCategory` wins when set (the newer, more
/// specific field), else `discoverySourceType`, else [BuyerTypeFacet.unknown].
BuyerTypeFacet buyerTypeFacetFor(Opportunity opportunity) {
  final category = opportunity.tenderSourceCategory;
  if (category != null) {
    switch (category) {
      case TenderSourceCategory.governmentAgency:
      case TenderSourceCategory.countyGovernment:
        return BuyerTypeFacet.government;
      case TenderSourceCategory.developmentPartner:
        return BuyerTypeFacet.developmentPartner;
      case TenderSourceCategory.unAgency:
        return BuyerTypeFacet.unAgency;
      case TenderSourceCategory.ngo:
        return BuyerTypeFacet.ngo;
      case TenderSourceCategory.privateSector:
      case TenderSourceCategory.customEnterprise:
        return BuyerTypeFacet.privateSector;
    }
  }

  final discoveryType = opportunity.discoverySourceType;
  if (discoveryType != null) {
    switch (discoveryType) {
      case DiscoverySourceType.governmentProcurement:
        return BuyerTypeFacet.government;
      case DiscoverySourceType.developmentOrganization:
        return BuyerTypeFacet.developmentPartner;
      case DiscoverySourceType.unProcurement:
        return BuyerTypeFacet.unAgency;
      case DiscoverySourceType.ngo:
        return BuyerTypeFacet.ngo;
      case DiscoverySourceType.privateSector:
        return BuyerTypeFacet.privateSector;
      case DiscoverySourceType.rss:
      case DiscoverySourceType.api:
      case DiscoverySourceType.manual:
        return BuyerTypeFacet.unknown;
    }
  }

  return BuyerTypeFacet.unknown;
}

bool matchesBuyerTypeFacet(Opportunity opportunity, BuyerTypeFacet facet) {
  if (facet == BuyerTypeFacet.any) return true;
  return buyerTypeFacetFor(opportunity) == facet;
}

/// True when [opportunity]'s title, client, or reference/tender number
/// (`sourceUrl` is the closest honest proxy — there is no separate
/// tender-number field on the model) contains [query] (case-insensitive).
/// An empty query always matches.
bool matchesSearchQuery(Opportunity opportunity, String query) {
  final trimmed = query.trim().toLowerCase();
  if (trimmed.isEmpty) return true;
  return opportunity.title.toLowerCase().contains(trimmed) ||
      (opportunity.client?.toLowerCase().contains(trimmed) ?? false) ||
      opportunity.sourceUrl.toLowerCase().contains(trimmed);
}

/// The full set of currently-applied facet filters (BU selection aside,
/// which is handled separately by [matchesBuFilter] since it drives the
/// tab/segmented control rather than a chip row). All fields default to
/// "no constraint" so a freshly-opened filter bar matches everything.
class OpportunityFacetFilters {
  const OpportunityFacetFilters({
    this.searchQuery = '',
    this.stage,
    this.valueBand = ValueBand.any,
    this.deadlineWindow = DeadlineWindow.any,
    this.fitScoreThreshold = FitScoreThreshold.any,
    this.buyerType = BuyerTypeFacet.any,
  });

  final String searchQuery;

  /// Null means "Any stage" — distinct from any real [OpportunityPipelineStage]
  /// value, so there's no need for a synthetic "any" enum case here (unlike
  /// the other facets, which need one to stay a plain-old field default).
  final OpportunityPipelineStage? stage;
  final ValueBand valueBand;
  final DeadlineWindow deadlineWindow;
  final FitScoreThreshold fitScoreThreshold;
  final BuyerTypeFacet buyerType;

  bool get isEmpty =>
      searchQuery.trim().isEmpty &&
      stage == null &&
      valueBand == ValueBand.any &&
      deadlineWindow == DeadlineWindow.any &&
      fitScoreThreshold == FitScoreThreshold.any &&
      buyerType == BuyerTypeFacet.any;

  OpportunityFacetFilters copyWith({
    String? searchQuery,
    OpportunityPipelineStage? stage,
    bool clearStage = false,
    ValueBand? valueBand,
    DeadlineWindow? deadlineWindow,
    FitScoreThreshold? fitScoreThreshold,
    BuyerTypeFacet? buyerType,
  }) {
    return OpportunityFacetFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      stage: clearStage ? null : (stage ?? this.stage),
      valueBand: valueBand ?? this.valueBand,
      deadlineWindow: deadlineWindow ?? this.deadlineWindow,
      fitScoreThreshold: fitScoreThreshold ?? this.fitScoreThreshold,
      buyerType: buyerType ?? this.buyerType,
    );
  }
}

/// Applies BU selection then every facet filter to [opportunities] — the
/// one function the Opportunities screen calls, so the compose order (BU
/// -> facets -> search) is defined once and is independently testable.
List<Opportunity> filterOpportunities(
  List<Opportunity> opportunities,
  OpportunityBuFilter buFilter,
  OpportunityFacetFilters facets, {
  required DateTime now,
}) {
  return opportunities.where((o) {
    if (!matchesBuFilter(o, buFilter)) return false;
    if (facets.stage != null && o.pipelineStage != facets.stage) return false;
    if (!matchesValueBand(o.estimatedBudget, facets.valueBand)) return false;
    if (!matchesDeadlineWindow(o.deadline, facets.deadlineWindow, now: now)) {
      return false;
    }
    if (!matchesFitScoreThreshold(
      o.fitScorePercent,
      facets.fitScoreThreshold,
    )) {
      return false;
    }
    if (!matchesBuyerTypeFacet(o, facets.buyerType)) return false;
    if (!matchesSearchQuery(o, facets.searchQuery)) return false;
    return true;
  }).toList();
}
