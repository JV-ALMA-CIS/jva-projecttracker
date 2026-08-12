# ADR-004 — AI Opportunity Match Analysis

## Status
Accepted (Milestone 3.4)

## Context
Milestone 3.3 answered "what is this opportunity" (classification).
Milestone 3.4 answers a different question over the same Company
Knowledge Graph: "how well does JV ALMA CIS match it" — an overall score,
eight category sub-scores, recommended supporting evidence (specific
products/business units/experiences/knowledge articles), and a strategic
read (strengths/gaps/risks/next actions). The brief explicitly said to
reuse the Milestone 3.3 parser architecture, so the central question this
ADR answers is *what to reuse verbatim, what to reuse via a small
refactor, and what to deliberately build differently* — not the shape of
the AI-integration boundary itself, which ADR-003 already settled.

## Decision

**1. Reused `buildKnowledgeGraph()` unchanged.** Both classification and
match analysis reason over the exact same Company Knowledge Graph
snapshot shape (`text` for the prompt, `validIds` for hallucination
filtering) — there was no reason to fetch it twice or maintain two
copies. `analyzeOpportunityMatch` calls the same function
`classifyOpportunity` does.

**2. Extracted a shared `retryAsync`/`callGeminiForJson` pair, replacing
Milestone 3.3's classification-specific `classifyOnce`/`classifyWithRetry`.**
The 3.3 versions were hardcoded to classification's validation step; since
match analysis needed the identical retry-on-failure shape (transient API
errors, timeouts, invalid JSON — all just "a failed attempt," retried the
same way), duplicating that loop a second time would have meant two
copies of the same bug surface. `retryAsync(attempt, {label, maxAttempts})`
takes the validation step as a parameter, so `classifyOpportunity` now
calls
`retryAsync(() => validateClassification(await callGeminiForJson(prompt), validIds), {label: "classifyOpportunity"})`
and `analyzeOpportunityMatch` calls the equivalent with
`validateMatchAnalysis`. This is a refactor of code introduced in the
immediately preceding milestone, not a change to any earlier, separately-
reviewed module — it doesn't touch `discoverApplicationAreas` or
`searchOpportunities`, which keep their own independent (non-retrying)
call shape.

**3. `recommendedProductIds`/`recommendedBusinessUnitIds`/
`recommendedExperienceIds`/`recommendedKnowledgeArticleIds`** — named with
the `Ids` suffix, not the brief's literal `recommendedProducts` /
`recommendedBusinessUnits` / etc. Every relationship field across every
Company Intelligence entity and both prior Opportunity AI milestones uses
an `Ids` suffix without exception; this was already decided explicitly
during Milestone 2.5 (business units vs. business unit IDs) and confirmed
by that same convention being used consistently ever since. Naming these
four fields without the suffix would be the first inconsistency in an
otherwise uniform, repo-wide convention, for a distinction the rest of the
app has never needed to make.

**4. `matchAnalyzedAt` was added even though the brief's OUTPUT list didn't
name it.** Every other AI-populated field set on `Opportunity`
(classification's `aiReviewedAt`) has a companion timestamp recording when
that AI pass last ran; the milestone's own UI section asks for "AI
timestamp"-equivalent context implicitly by asking to display when
analysis last ran (mirrored from classification's "AI timestamp"
requirement in 3.3). Omitting it would have left match analysis as the one
AI pass in the app with no way to tell freshness from staleness.

**5. No `matchAnalysisStatus` enum was added**, unlike classification's
`classificationStatus` (`notClassified`/`processing`/`classified`/
`needsReview`). The brief didn't ask for one, and match analysis has no
distinct states worth encoding beyond "has it run" (`overallMatchScore ==
null` already answers that) — adding a parallel status enum here would
have been the exact kind of un-asked-for field ADR-002 already flagged as
a risk (too many overlapping "where is this" fields on one document).
Consequently `analyzeOpportunityMatch` also skips classification's
"processing" intermediate Firestore write — there's no status field to set
it on, and the client's own loading spinner already covers that transient
state.

**6. `OpportunityMatchAnalysisScreen` is read-only — deliberately unlike
`OpportunityClassificationScreen`.** The brief's UI section for this
milestone lists only "Display: ...", never repeating 3.3's explicit
"Allow manual editing after AI completes." Match analysis is framed as an
AI insight report (scores, strengths, recommended evidence, strategic
read) that gets *regenerated* wholesale by re-running analysis, not
hand-corrected field by field the way a classification can be overridden.
This made the screen substantially simpler: no `TextEditingController`s,
no save button, no local seed-once state — it's a `ConsumerStatefulWidget`
purely so it can hold an `_analyzing` loading flag; everything else
renders directly from the live `opportunityByIdProvider` stream.

**7. A new `RecommendedEntityChips<T>` widget**, distinct from the
existing `RelationshipPicker<T>`. `RelationshipPicker` is for *editable*
selection (a toggleable `FilterChip` per option); this screen only needs
to *display* AI-recommended entities by resolved name, with no selection
state at all — reusing `RelationshipPicker` for a read-only display would
have meant either misusing its `onToggle` callback or forking its
internals. The two widgets share the same `optionsAsync`/`idOf`/`nameOf`
shape so both are easy to reason about side by side.

**8. Scores render as plain `Chip`/`Text` (`"Label: NN%"`), never a gauge
or progress-bar widget.** Same reasoning as ADR-003's confidence-score
decision: `fit_score_badge.dart` still carries its "only percentage
widget in the app" comment, now stale across three AI-integration
milestones (`fitScorePercent`, `confidenceScore`, and as of this milestone
nine more score fields). Introducing a new gauge-style widget here would
add a *third* visual language for percentages. Restated as a stronger
recommendation below — this is no longer a one-off comment to revisit, it's
a pattern across four fields now.

## Alternatives Considered

- **A single shared `AIAnalysisResult`/generic parser for both
  classification and match analysis.** Considered, given how similar
  `AIClassificationResult`/`MatchAnalysisResult` and their parsers are.
  Rejected — the two field sets are disjoint (no field appears in both),
  and a generic/shared type would need either a large optional-everything
  union or a generics-based scheme for little real benefit; two small,
  independently-testable parser files (mirroring each other in shape, not
  sharing code) stayed easier to read and change independently.
- **Making `OpportunityMatchAnalysisScreen` editable like classification.**
  Rejected per Decision 6 — the brief's own asymmetry between the two
  milestones' UI sections was read as intentional.
- **Reusing `RelationshipPicker` in read-only mode** (e.g. by passing a
  no-op `onToggle` and disabling interaction). Rejected — would leave dead
  selection-toggle plumbing in a widget that's supposed to be purely
  informational; a second, smaller widget was clearer.
- **A `matchAnalysisStatus` enum mirroring `classificationStatus`.**
  Rejected per Decision 5.

## Consequences

- No Firestore schema migration: 19 new fields on `Opportunity`, all
  nullable/empty by default, verified by a model-shaped parser test
  (`defaults missing scores/recommendations/lists gracefully`) analogous to
  Milestone 3.3's legacy-document test.
- No new Firestore rules or indexes required — `analyzeOpportunityMatch`
  reads the same collections `classifyOpportunity` already reads, and
  writes only to `opportunities` fields already covered by the existing
  rule.
- No new npm dependency — `analyzeOpportunityMatch` reuses
  `buildKnowledgeGraph`/`callGeminiForJson`/`retryAsync`/`genAiClient` in
  full.
- Same Cloud Functions test-coverage gap noted in ADR-003 applies here too
  (`validateMatchAnalysis`/`buildMatchAnalysisPrompt` have no Node-side
  automated tests) — unchanged from the prior milestone, not a new gap.
- `Opportunity` now carries classification (3.1/3.3), pipeline (3.2), and
  match-analysis (3.4) fields side by side — over 50 fields on one model.
  Nothing about this milestone's fields overlaps with the other two groups
  by name or meaning, so no immediate confusion, but the model file itself
  is now long enough that a future milestone should consider whether
  Opportunity needs splitting (see recommendation below).

## Architectural Recommendations

- **The `fit_score_badge.dart` "only percentage widget" comment should be
  updated or the constraint formally retired.** This is the third ADR in a
  row (3, and now 4) that has had to explain why a new AI-produced
  percentage isn't reusing `FitScoreBadge`. The comment was accurate when
  `fitScorePercent` was the only real percentage in the app; it no longer
  is, and leaving it as-is just means every future milestone re-litigates
  the same footnote.
- **Consider whether `Opportunity` should be decomposed.** With
  classification, pipeline, and match-analysis fields all on one document
  (and all three sharing the same collection/rules/indexes by design), the
  Dart model file is now long. This isn't causing a concrete problem yet —
  Firestore documents are cheap to make wide, and every field here is
  genuinely 1:1 with a single opportunity — but if a fifth AI capability is
  added in the same spirit, it's worth deciding then whether some of these
  groups belong in subcollections instead.
- **`status`, `pipelineStage`, and `classificationStatus` are three
  overlapping "where is this" fields** (ADR-002, ADR-003). Match analysis
  doesn't add a fourth, by design (Decision 5), but the existing three are
  still worth reconciling before anything else in this family gets added.
