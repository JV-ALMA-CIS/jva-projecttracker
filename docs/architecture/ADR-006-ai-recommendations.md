# ADR-006 — AI Recommendations

## Status
Accepted (Milestone 3.6)

## Context
Milestones 3.3-3.5 each run one AI pass scoped to a *single* opportunity
(classification, match analysis, strategic review), writing results onto
that one `Opportunity` document. Milestone 3.6 is different in kind: a
**portfolio-wide recommendations engine** that reasons over *every*
opportunity — using their already-computed classification/match-analysis/
strategic-review fields as input signal, not re-deriving them — plus the
Company Knowledge Graph, and produces a handful of prioritized, explainable
business recommendations (e.g. "fast-track this tender," "this opportunity
looks stalled," "consider developing this capability"). This was an
explicit, user-confirmed scope decision before implementation began (the
milestone name alone didn't disambiguate a portfolio-wide engine from a
fourth per-opportunity AI pass or a purely-derived dashboard widget with no
new AI call).

## Decision

**1. `searchOpportunities`/`triggerDiscoveryRun`/`scheduledOpportunityDiscovery`
(Phase 1) is the closer precedent than 3.3-3.5, because this feature creates
multiple new documents in a batch rather than mutating one existing
document.** The Cloud Function fetches context once, calls Gemini once for
a JSON *array* of candidates, validates each candidate independently
(skipping bad ones rather than discarding the whole batch — a new nuance,
since 3.3-3.5's validators handle one object, not an array of independent
items), writes valid ones as new Firestore documents, and returns just
`{created: number}`. A scheduled counterpart,
`scheduledRecommendationRefresh` (Monday 09:00, one hour after the existing
Monday 08:00 discovery run so newly-discovered opportunities are already in
Firestore when recommendations reason over the portfolio), mirrors
`scheduledOpportunityDiscovery` for the same reason: a daily/weekly-use tool
shouldn't require a manual click to stay fresh.

**2. No dedicated parser file for the trigger response — unlike 3.3-3.5.**
Those three needed parsers because their Cloud Functions return the full AI
payload for immediate no-wait client rendering (the calling screen applies
the result locally so the UI doesn't wait for the Firestore stream to
catch up). Recommendations don't need that: the client only needs a count
for a snackbar (exactly like `OpportunityService.triggerDiscoveryRun` inlines
`(result.data['created'] as num?)?.toInt() ?? 0` with no parser file), and
the actual recommendation documents render via the live Firestore stream
through `Recommendation.fromMap` — which *is* the client-side validation
layer for data the Cloud Function already validated before writing. Adding a
parser file here would validate a return value nothing downstream uses.

**3. `RecommendationEngineService.generateRecommendations()` treats a
`null`/count-less response as `0`, not a thrown exception** — unlike
3.3-3.5's services, which throw when their single-object payload is
unusable. A batch operation that created zero new items isn't a failure
state (it may simply mean nothing new stood out this run); this matches
`triggerDiscoveryRun`'s existing precedent of never treating an empty/absent
`created` count as an error.

**4. Two separate service classes, matching the established split.** A
`RecommendationService` (collection CRUD: `watchAll`/`create`/`dismiss`/
`markActioned`, mirroring `OpportunityEventService`'s shape) plus a
dedicated `RecommendationEngineService` (the AI trigger only,
`RecommendationEngineException`, lazy `FirebaseFunctions`, `invokeOverride`
test seam — mirroring `StrategicReviewService`'s shape). Every AI-trigger
since ADR-003 gets its own dedicated service class regardless of which
collection it writes to (`AIClassificationService`/`MatchAnalysisService`/
`StrategicReviewService` are all separate from `OpportunityService`, even
though they mutate opportunities `OpportunityService` already owns).
`triggerDiscoveryRun`-inside-`OpportunityService` is legacy Phase-1 code that
predates this convention, not the pattern to replicate going forward — this
ADR follows the newer convention for the trigger half while following the
Phase-1 shape only for the *batch-creation-with-scheduling* mechanics
(Decision 1).

**5. `priority` reuses the existing `OpportunityPriority` enum** (already
has an `opportunityPriorityLabel` translation in `AppStrings`) instead of a
duplicate low/medium/high enum — directly satisfies "avoid duplicating
logic." `RecommendationCategory` (`priorityOpportunity`, `atRiskOpportunity`,
`capabilityGap`, `resourceAllocation`, `general`) and `RecommendationStatus`
(`active`, `dismissed`, `actioned`) are genuinely new concepts with no
existing equivalent to reuse.

**6. Dismiss/mark-actioned are in scope, unlike the read-only 3.4/3.5
screens.** Those screens are read-only AI *reports* on one opportunity;
`RecommendationsScreen` is a daily triage *feed* for BD managers/executives
— matching this project's explicit design philosophy of dashboards and
"surface the most important actions first" over static reports. These
actions only change the recommendation's *own lifecycle status* (mirrors
`OpportunityService.updateStatus`'s narrow status-only update) — they don't
touch 3.5's read-only relationship-chip rule, which was specifically about
knowledge-graph relationship editing, not an entity's own triage state.

**7. No new bottom-nav destination.** `home_shell.dart` has 5 destinations
today; Company Intelligence already bundles 8 entities under a single nav
destination, showing this app doesn't give every new entity its own
top-level tab. Recommendations surface as a Dashboard section (top-3, using
`topRecommendationsProvider`) with a "View all" action pushing a dedicated
`RecommendationsScreen` via `pushSlideFade` — the same navigation shape
opportunity detail screens already use.

**8. One reusable `RecommendationCard` widget, used in both places.**
Optional `onDismiss`/`onMarkActioned` callbacks and a `compact` flag:
the Dashboard's top-3 render it compact with no action callbacks (tap
navigates to the full screen instead); the full screen renders it non-compact
with both actions wired to `RecommendationService`. Category maps to an
icon; priority renders as a `Chip` colored via
`colorScheme.errorContainer`/`tertiaryContainer`/`surfaceContainerHighest`
for high/medium/low — still a plain `Chip`, not a new gauge/badge widget, so
this doesn't contradict ADR-004/005's "no new percentage visual language"
decision (which was specifically about score *percentages*, not categorical
priority). Related-entity chips reuse `RecommendedEntityChips<T>` unchanged
for all 8 Company Intelligence categories plus a 9th use for
`relatedOpportunityIds` (the widget is already generic over `T`).

**9. Firestore: new `recommendations` collection + rule, no new index.**
`watchAll()` orders by a single field (`generatedAt` descending) — no
composite index needed. The dedup check
(`where('status','==','active').where('title','==', title)`) is two
equality filters, served from Firestore's automatic single-field indexes
with no composite index required (composite indexes are only needed for
range-filter/orderBy combinations, not multiple `==` filters) — matches the
"no index changes" outcome of ADR-004/005.

**10. `category`/`priority` fall back to `"general"`/`"medium"` in the
Cloud Function validator, unlike most other AI features' optional enums
that fall back to `null`.** These two fields drive how every recommendation
groups/sorts/colors in the UI (`activeRecommendationsProvider`'s sort,
`RecommendationCard`'s icon/color) — leaving them `null` would mean every
render site needs its own fallback logic. This mirrors classification's
`classificationStatus` (which similarly can't be left null, falling back to
`needsReview`) more than match analysis/strategic review's purely optional
enums, because — like classification's status — these values are load-
bearing for the UI, not purely descriptive.

## Alternatives Considered

- **A fourth per-opportunity AI pass** (e.g. "recommended next steps" on
  `Opportunity` itself). Rejected — the user confirmed portfolio-wide scope,
  and it would have significantly overlapped with 3.5's
  `nextRecommendedActions`/executive recommendation.
- **A purely-derived Dashboard widget with no new Cloud Function**, just
  re-presenting existing per-opportunity AI fields. Rejected — the user
  confirmed a real AI reasoning pass was wanted, not a re-sort of existing
  data.
- **Folding the trigger into `OpportunityService`** (matching
  `triggerDiscoveryRun`'s exact placement). Rejected per Decision 4 — the
  newer, more deliberate per-AI-feature service convention outweighs
  matching Phase-1 code that predates it.
- **A composite Firestore index for the dedup query.** Unnecessary per
  Decision 9 — multiple equality filters don't require one.
- **A 6th bottom-nav destination.** Rejected per Decision 7.

## Consequences

- New Firestore collection (`recommendations`) with its own rule; no index
  changes required (Decision 9).
- No new npm dependency — `generateRecommendations`/
  `scheduledRecommendationRefresh` reuse `buildKnowledgeGraph`/
  `callGeminiForJson`/`retryAsync`/`genAiClient` in full, adding only
  `buildOpportunityPortfolioSummary()` as new portfolio-level context.
- Same Cloud Functions test-coverage gap noted in ADR-003/004/005 applies
  here too (`validateRecommendationItem`/`buildRecommendationsPrompt` have
  no Node-side automated tests).
- This is the first genuinely new *entity* since Phase 2 (own model/
  service/providers/screen/tests), directly addressing the technical debt
  this project already flagged ("Opportunity model is becoming very large...
  consider subcollections if AI fields continue to grow") by *not* adding a
  4th field group to `Opportunity` — the new intelligence lives in its own
  collection instead.
- A new automatically-scheduled Cloud Function (`scheduledRecommendationRefresh`)
  means Gemini calls will run weekly once deployed, even with no user
  interaction — same cost/operational profile as the existing
  `scheduledOpportunityDiscovery`, just one more scheduled job.

## Architectural Recommendations

- **Dedup-by-exact-title is a coarse safety net, not true de-duplication.**
  It prevents literal duplicate titles from piling up across weekly runs,
  but two recommendations describing the same underlying issue with
  slightly different wording will both persist. If this becomes noisy in
  practice, a future milestone should consider dedup by
  (`category` + primary `relatedOpportunityIds` entry) instead of/in
  addition to title.
- **Recommendations currently have no expiry.** An `active` recommendation
  about a since-resolved situation (e.g. an opportunity that was later
  pursued anyway, or lost) stays active until a user manually dismisses it.
  A future milestone could auto-expire or re-evaluate recommendations
  referencing an opportunity whose `status`/`pipelineStage` has since
  changed significantly.
- **This is a natural foundation for Milestone 3.7 (Notifications):** a new
  high-priority `active` recommendation is exactly the kind of event a
  notification system would want to alert on. The `recommendations`
  collection's `status`/`priority`/`generatedAt` fields are already shaped
  to support that without a schema change.
