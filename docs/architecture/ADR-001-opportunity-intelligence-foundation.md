# ADR-001 — Opportunity Intelligence Foundation

## Status
Accepted (Milestone 3.1)

## Context
Opportunities are discovered automatically today by the `searchOpportunities` /
`scheduledOpportunityDiscovery` Cloud Functions, which write a small, fixed
shape into the `opportunities` collection (`title`, `description`, `sourceUrl`,
`client`, `deadline`, `status`, `fitScorePercent`, `fitReasoning`, `tags`,
`discoveredAt`, `updatedAt`) — see `functions/index.js`.

Milestone 3.1 asks for the *data foundation* an eventual AI classification
pass can populate after analyzing tender documents: a classification status,
a confidence/risk/priority assessment, estimated budget/duration/complexity,
and — critically — the links from an opportunity into the rest of the
Company Intelligence knowledge graph (BusinessUnit, Product, Service,
Capability, Technology, Industry, Experience, KnowledgeArticle). No AI, no
Cloud Function, and no new collection were in scope for this milestone —
only the schema and a manual editing surface.

Three concrete decisions had to be made that the milestone brief didn't
fully specify:

1. Which new fields are genuinely nullable vs. given a non-null default.
2. Whether `estimatedComplexity`/`riskLevel`/`priority` should be free-form
   strings or enums, given the brief only mandated an enum for
   `classificationStatus`.
3. Where the manual editing UI lives, since `Opportunity` — unlike every
   Company Intelligence entity — has no existing create/edit form (it's
   never manually created, only AI-discovered).

## Decision

**1. Extend the existing `Opportunity` model and collection in place.**
No new collection, per the brief. `Opportunity.fromMap` defaults every new
field exactly the way every other model in this codebase already handles
missing keys, so documents written by the existing Cloud Function (which
has none of these fields) keep parsing correctly with no migration. A new
model test (`Opportunity defaults classification fields when reading a
pre-Milestone-3.1 document`) pins this down by round-tripping a map shaped
exactly like what `functions/index.js` writes today.

**2. Typing per field, chosen for semantic accuracy over literal
"nullable everything":**
- `classificationStatus`: **non-nullable enum**, default `notClassified`.
  The enum already has an explicit "unset" value, so a nullable wrapper
  would be redundant — same pattern as every other status enum in the app
  (`ProjectStatus`, `ApplicationStatus`, etc., all default rather than
  null).
- `classificationSummary`, `opportunityType`, `estimatedDuration`: `String?`.
  Free text, "not yet set" is a real state distinct from an empty string.
- `industryIds`, `technologyIds`, `businessUnitIds`, `productIds`,
  `serviceIds`, `capabilityIds`, `experienceIds`, `knowledgeArticleIds`:
  **non-nullable `List<String>`**, default `const []`. Every relationship
  field across all eight existing Company Intelligence entities uses this
  exact shape; an empty list already means "none," so a nullable list
  would be a first-of-its-kind inconsistency for no benefit.
- `estimatedBudget`: `double?`, mirroring `Experience.contractValue`.
- `confidenceScore`: `int?`. Deliberately *not* defaulted to `0` like the
  sibling field `fitScorePercent` — `fitScorePercent` is always populated at
  discovery time, but `confidenceScore` comes from a classification pass
  that may never have run, and null vs. "scored as zero confidence" are
  different facts an AI (or a human) needs to distinguish.
- `estimatedComplexity`, `riskLevel`, `priority`: **nullable enums**
  (`EstimatedComplexity?`, `RiskLevel?`, `OpportunityPriority?`), each with
  three values (`low`/`medium`/`high`). Only `ClassificationStatus` was
  mandated as an enum by the brief, but these three are small, fixed,
  closed sets exactly like every other enum in this codebase (as opposed to
  `category`/`sector`/`fundingSource`-style fields, which are free strings
  specifically because new values need to be addable without a code
  change). Modeling them as enums keeps them type-safe and gives the editor
  UI a dropdown for free, consistent with how every comparable field in the
  app is handled.
- `aiReviewedAt`: `DateTime?`, mirroring `Application
  .applicationAreasUpdatedAt` — null means "AI has never reviewed this."

**3. A dedicated `OpportunityClassificationScreen`, reached by a new
"Edit classification" action on each opportunity's existing expansion
tile**, rather than either (a) inlining ~15 new editable fields directly
into the tile, or (b) reusing the `<entity>_form_screen.dart` naming/shape
used by Projects/Applications/the Company Intelligence entities.
`Opportunity` has no "create" form — opportunities are never manually
created — so this screen only ever edits an existing document
(`opportunityId` is required, not nullable), which is why it isn't named
`opportunity_form_screen.dart`. Pushing a full screen (via the same
`pushSlideFade` used everywhere else) keeps the interaction pattern
consistent with the rest of the app, rather than making the Opportunities
list the one screen with a giant inline form per row.

**4. `aiReviewedAt` is round-tripped but never manually editable.** It's a
signal of when AI last touched the record; exposing it to manual editing
would let a human fake that signal, which defeats its purpose once a real
classification pass exists.

**5. `OpportunityService` gained a general `update(Opportunity)` method**
(alongside the existing narrow `updateStatus`), because the classification
editor needs to write many fields at once. This follows the exact
`_collection.doc(id).update(opportunity.toMap())` shape already used by
every other Company Intelligence service.

**6. Fixed an unrelated pre-existing constructor issue in
`OpportunityService`** discovered while wiring up `fake_cloud_firestore`
tests: the constructor eagerly evaluated `FirebaseFunctions.instance` in
its initializer list, which threw `[core/no-app]` in any test that
constructed the service with only a fake Firestore and never touched
`triggerDiscoveryRun`. `_functions` is now resolved lazily via a getter, so
Firebase Core only needs to be initialized if `triggerDiscoveryRun` is
actually called — matching how every other service in the app is
constructed for testing.

## Alternatives Considered

- **New `opportunityClassifications` collection, joined by `opportunityId`.**
  Rejected — the brief explicitly says "do not create a new collection,"
  and a 1:1 side-table would just be the same data with an extra join for
  no isolation benefit (nothing else ever reads classification data
  independently of its opportunity).
- **Nullable `List<String>?` for every relationship field**, taking the
  brief's "add nullable fields" instruction fully literally. Rejected in
  favor of consistency with all eight existing Company Intelligence
  entities, which use non-nullable empty-list-by-default lists; introducing
  a nullable-list idiom here would be the first inconsistency in an
  otherwise uniform convention, for a distinction (`null` vs. `[]`) nothing
  in the app currently needs to make.
- **Free-string `estimatedComplexity`/`riskLevel`/`priority`** (like
  `category` on Technology/Industry/KnowledgeArticle). Rejected because
  those three are genuinely closed, small sets — unlike categories, there's
  no plausible need to add a fourth "risk level" without a code change — so
  an enum gives type safety and a dropdown UI for free, at zero flexibility
  cost.
- **Reusing `FitScoreBadge` to render `confidenceScore`.** Rejected —
  `fit_score_badge.dart` carries an explicit doc comment that it is "the
  only widget in the app that displays a percentage" and must not be
  duplicated, on the grounds that `fitScorePercent` was, until now, the
  only real AI-produced percentage in the app. `confidenceScore` is
  manually entered today, not AI-produced, so reusing that widget would
  both violate its stated invariant and visually imply an AI provenance
  the value doesn't have yet. Rendered instead as a plain `Chip` with
  `"Confidence: NN%"` text. See Architectural Recommendations below —
  this constraint is worth revisiting once real AI scoring exists for both
  fields.
- **Inlining all new fields directly into the `_OpportunitiesTile`
  expansion content.** Rejected in favor of the dedicated
  `OpportunityClassificationScreen` (see Decision 3) — mainly for UI
  density and consistency with the rest of the app's push-a-form-screen
  pattern, not for a technical reason.

## Consequences

- Existing Cloud-Function-written opportunity documents are unaffected and
  require no backfill; every new field defaults safely on read.
- No Firestore rules or index changes were required — the existing
  `opportunities` rule/index (on `status` + `fitScorePercent`) already
  covers every query this milestone adds, since all new filtering is
  client-side.
- The knowledge-graph relationship fields on `Opportunity` are structurally
  ready for a future classification pass to populate via
  `OpportunityService.update()`; nothing about today's manual-editing UI
  needs to change when that pass is built — it can call the same method.
- `fit_score_badge.dart`'s "only percentage widget" comment is now
  technically slightly stale (there are two percentage-shaped fields on
  `Opportunity`), even though no shared widget was introduced. Flagged as a
  recommendation, not fixed here, since resolving it well depends on
  product decisions this milestone was explicitly told not to make (how AI
  scoring and AI classification confidence should visually relate to each
  other).
