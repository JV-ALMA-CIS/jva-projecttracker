# ADR-005 — AI Strategic Review

## Status
Accepted (Milestone 3.5)

## Context
Milestone 3.3 answered "what is this opportunity" (classification). Milestone
3.4 answered "how well does JV ALMA CIS match it" (match analysis). Milestone
3.5 sits on top of both and answers the executive question: "should we
pursue this opportunity, and how" — an executive recommendation
(pursue/pursue with caution/do not pursue), an executive summary, strategic
strengths/weaknesses/risks/mitigations/competitive advantages/missing
requirements, which business units should lead, which products/services/
capabilities/technologies to highlight, a proposal positioning strategy, and
next recommended actions. The brief explicitly said to follow the existing
architecture exactly, so — as with ADR-004 — the central question this ADR
answers is what to reuse verbatim and what had to be built differently, not
the shape of the AI-integration boundary itself (already settled by
ADR-003/ADR-004).

## Decision

**1. Reused `buildKnowledgeGraph()`/`callGeminiForJson()`/`retryAsync()`
unchanged.** All three AI passes (classification, match analysis, strategic
review) reason over the identical Company Knowledge Graph snapshot and share
the identical retry-on-failure shape. `generateStrategicReview` calls the
same functions `classifyOpportunity` and `analyzeOpportunityMatch` already
call — no new npm dependency, no duplicated retry loop.

**2. Every strategic-review field on `Opportunity` is prefixed
(`strategicReview*Ids` for recommended entities, `strategic*` for several
narrative lists) instead of using the brief's plain field names.** This is
the one deliberate deviation from a literal reading of the brief, and it's
forced by a genuine naming collision: Milestone 3.4 already put
`recommendedProductIds`, `recommendedBusinessUnitIds`,
`recommendedExperienceIds`, `recommendedKnowledgeArticleIds`, `strengths`,
`gaps`, `risks`, `nextActions`, and `strategicRecommendation` (a narrative
string) on the same `Opportunity` document. Milestone 3.5 needs a
*different* set of recommended entities — 7 categories
(BusinessUnits/Products/Services/Capabilities/Technologies/Experiences/
KnowledgeArticles) instead of match analysis's 4 — and different narrative
fields that must coexist with, not overwrite, 3.4's fields on the same
document. Reusing the bare names would mean one AI pass silently clobbering
another's output. Resolution:
  - Recommended entities → `strategicReviewBusinessUnitIds`,
    `strategicReviewProductIds`, `strategicReviewServiceIds`,
    `strategicReviewCapabilityIds`, `strategicReviewTechnologyIds`,
    `strategicReviewExperienceIds`, `strategicReviewKnowledgeArticleIds` —
    exactly the 7 entity types the brief's own Display list names (Industries
    is deliberately not one of them; the brief doesn't ask for "Recommended
    Industries," matching the same selective-subset precedent set by
    ADR-004 Decision 3).
  - Narrative lists → `strategicStrengths`, `strategicWeaknesses`,
    `strategicRisks`, `mitigationStrategies`, `competitiveAdvantages`,
    `missingRequirements`, `nextRecommendedActions`.
  - Headline fields → `executiveRecommendation` (new enum
    `StrategicReviewRecommendation { pursue, pursueWithCaution,
    doNotPursue }`), `executiveSummary`, `proposalPositioningStrategy`,
    `strategicReviewedAt`.
  This keeps the `Ids` suffix convention from ADR-004 Decision 3 fully
  intact — only the entity-type segment of each name changed, not the
  suffix.

**3. `executiveRecommendation` is nullable, with no forced fallback value —
mirroring match analysis, not classification.** Classification's
`classificationStatus` always resolves to a concrete value (defaulting to
`needsReview` if the model's output was unusable), because that field
doubles as an implicit "has this run yet" signal. Match analysis rejected an
equivalent status enum entirely (ADR-004 Decision 5): "has it run" is
answered by `overallMatchScore == null`. Strategic review follows match
analysis's precedent, not classification's — `strategicReviewedAt == null`
already answers "has a review run," so `executiveRecommendation` doesn't
need to fake a default when the model's output is missing or invalid; it's
simply `null`, and the screen's empty-state check
(`executiveSummary == null && executiveRecommendation == null`) handles it
the same way match analysis's `overallMatchScore == null` check does.

**4. No `strategicReviewStatus` enum.** Same reasoning as ADR-004 Decision 5
— this is the second AI feature in a row to skip an "am I done yet" status
field, on the same "too many overlapping 'where is this' fields" grounds
ADR-002 originally flagged for `status`/`pipelineStage`/
`classificationStatus`. `generateStrategicReview` also skips an interim
"processing" write for the same reason `analyzeOpportunityMatch` does — the
client's own loading spinner already covers that transient state.

**5. The Cloud Function prompt explicitly includes the opportunity's
existing `classificationSummary` and match-analysis `strategicRecommendation`
(the narrative text)/`overallMatchScore` as context**, not just
title/description. This directly satisfies the brief's requirement that the
AI "must reason over ... Opportunity Classification [and] Opportunity Match
Analysis" — rather than have the strategic-review prompt re-derive a
classification or match assessment from scratch (duplicating work and
risking a contradictory second opinion), it treats the two earlier AI
passes' outputs as already-established facts to reason on top of. If either
prior pass hasn't run yet, the prompt says so explicitly
(`"(not yet classified)"` / `"(not yet analyzed)"`) rather than sending an
empty string with no context.

**6. `OpportunityStrategicReviewScreen` is read-only — like
`OpportunityMatchAnalysisScreen`, unlike `OpportunityClassificationScreen`.**
The brief's own Functional Requirements section says "Use read-only
recommendation chips, not editable relationship pickers" — an explicit,
unambiguous signal (stronger than match analysis's implicit signal in
ADR-004 Decision 6) that this screen should follow the read-only report
shape: a `ConsumerStatefulWidget` holding only a `_generating` loading flag,
re-run wholesale via "Run Strategic Review," rendering directly from the
live `opportunityByIdProvider` stream — no controllers, no save button, no
local seed-once state.

**7. `RecommendedEntityChips<T>` reused unchanged for all 7 entity-type
sections**, exactly as ADR-004 introduced it. Four of the seven sections
(Business Units, Products, Experiences, Knowledge Articles) also reuse
match analysis's existing `AppStrings` label getters
(`recommendedBusinessUnitsLabel`, `recommendedProductsLabel`,
`recommendedExperiencesLabel`, `recommendedKnowledgeLabel`) since the
*display text* for "Recommended Products" is identical regardless of which
AI feature populated the underlying (differently-named) field; only three
new label getters were needed, for the three entity types match analysis
never displayed (`recommendedServicesLabel`, `recommendedCapabilitiesLabel`,
`recommendedTechnologiesLabel`).

**8. Executive Recommendation renders as a plain `Chip`, not a colored
badge or gauge.** Same reasoning as ADR-003/ADR-004's percentage-widget
decisions — introducing severity-coded styling here would add yet another
visual language on top of the three percentage-rendering styles already
flagged as inconsistent (see Architectural Recommendations below).

## Alternatives Considered

- **Reusing Milestone 3.4's bare field names** (`recommendedProductIds`,
  `strengths`, etc.) for strategic review too, since both features
  conceptually "recommend" knowledge-graph entities. Rejected — the two
  features must produce independent, non-overwriting results on the same
  document (a user might re-run match analysis without re-running strategic
  review, or vice versa), so sharing field names was never viable once both
  are on the same model.
- **A `strategicReviewStatus` enum mirroring `classificationStatus`.**
  Rejected per Decision 4, consistent with ADR-004 Decision 5.
- **A generic/shared AI-result parser type across all three AI features.**
  Rejected for the same reason ADR-004 rejected it: the three field sets are
  disjoint, and three small, independently-testable parser files stay easier
  to read and change independently than one generic/optional-everything
  type.
- **Making `OpportunityStrategicReviewScreen` editable.** Rejected per
  Decision 6 — the brief is explicit here, more so than it was for match
  analysis.

## Consequences

- No Firestore schema migration: 18 new fields on `Opportunity`, all
  nullable/empty by default, verified by both a full round-trip test and an
  extended pre-Milestone-3.1 legacy-document defaults test (same shape as
  ADR-004's coverage).
- No new Firestore rules or indexes required — `generateStrategicReview`
  reads the same collections `classifyOpportunity`/`analyzeOpportunityMatch`
  already read, and writes only to `opportunities` fields already covered by
  the existing blanket rule.
- No new npm dependency — `generateStrategicReview` reuses
  `buildKnowledgeGraph`/`callGeminiForJson`/`retryAsync`/`genAiClient` in
  full.
- Same Cloud Functions test-coverage gap noted in ADR-003/ADR-004 applies
  here too (`validateStrategicReview`/`buildStrategicReviewPrompt` have no
  Node-side automated tests) — unchanged from the prior two milestones, not
  a new gap.
- `Opportunity` now carries classification (3.1/3.3), pipeline (3.2), match
  analysis (3.4), and strategic review (3.5) fields side by side — close to
  90 fields on one model. As ADR-004 already flagged, this isn't causing a
  concrete problem (every field is still genuinely 1:1 with a single
  opportunity, and Firestore documents are cheap to make wide), but the
  model file is now long enough that this is the second ADR in a row
  deferring, rather than acting on, the decomposition question below.

## Architectural Recommendations

- **The `fit_score_badge.dart` "only percentage widget" comment should
  finally be updated or retired** — this is the third ADR in a row (3, 4,
  and now 5) noting that a new AI-produced value isn't reusing
  `FitScoreBadge`/a gauge widget. Restating ADR-004's own recommendation: if
  a sixth AI-facing value is added under the same philosophy, this stops
  being a footnote and becomes worth actually fixing.
- **`Opportunity` decomposition is now a stronger candidate than ADR-004
  assessed it to be.** Three AI passes' worth of fields (classification,
  match analysis, strategic review) plus pipeline fields are all on one
  document. Nothing overlaps by name (thanks to Decision 2's prefixing) or
  by meaning, so there's still no correctness problem — but if a fourth AI
  capability is added in the same spirit, it's worth seriously considering
  subcollections (e.g. `opportunities/{id}/aiReviews/{milestone}`) rather
  than a fourth prefixed field group on the same flat document.
- **The field-name-collision problem this ADR solved via prefixing is
  itself worth watching.** Prefixing worked cleanly here because only two
  prior milestones' fields existed to collide with. A future AI milestone
  should check the full existing field list on `Opportunity` *before*
  choosing names, the same way this milestone did — not assume a fresh
  brief's suggested names are collision-free.
