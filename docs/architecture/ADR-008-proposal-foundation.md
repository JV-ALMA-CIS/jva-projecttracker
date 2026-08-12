# ADR-008 — Proposal Foundation

## Status
Accepted (Milestone 4.1)

## Context
Phase 4 ("Proposal Workspace") is the next stage of the Opportunity
Lifecycle after Strategic Review — `OpportunityPipelineStage` already
reserves `approved → proposalStarted → proposalReady → submitted` for it.
Milestone 4.1 lays the foundation: the `Proposal`/`ProposalSection` entities,
their services/providers, and a manual (no-AI-yet) workspace screen. AI
generation is Milestone 4.2; Document Library is 4.3; Submission Tracking
is 4.4 — this ADR only covers 4.1, per the Phase 4 architecture plan already
agreed with the user before implementation began.

The brief for this milestone was explicit that the workspace must feel like
"Microsoft Loop, Notion AI, Linear, and modern Google Workspace rather than
Microsoft Word" — a materially higher UX bar than a typical CRUD screen,
and several decisions below exist specifically to meet it.

## Decision

**1. `ProposalSection` is its own collection (`proposalSections`, keyed by
`proposalId`), not an array embedded on `Proposal`.** Per this project's
Architecture Principle 4 ("Never embed entire objects"), and matching the
existing `opportunityEvents` precedent (flat collection + foreign-key
field, never a nested subcollection). This also means Milestone 4.2's AI
generator will be able to regenerate a single section with one document
write, not a whole-proposal rewrite.

**2. Both new enums were deliberately trimmed to only what 4.1 can reach —
no forward-declared, unreachable states.** The Phase 4 architecture plan
sketched `ProposalStatus` with 4 values and `ProposalSectionStatus` with 4
(including `aiDrafted`/`finalized`), anticipating 4.2/4.4. Implementing
that now would leave states nothing could ever produce this milestone —
exactly the kind of "half-finished implementation" this project's own
coding standards warn against. So:
   - `ProposalStatus` ships with just `{draft, readyForReview}` this
     milestone. `finalized` is deferred to Milestone 4.4, where Submission
     Tracking will actually give it meaning.
   - `ProposalSectionStatus` ships with just `{notStarted, edited, approved}`.
     `aiDrafted` is deferred to 4.2, where the AI generator will actually
     produce it.
   Both are safe, additive enum changes later — Dart enums stored as
   strings need no migration to gain a new value.

**3. `Proposal.executiveSummary`/`winThemes` (from the Phase 4 sketch) were
dropped from the 4.1 model entirely**, not just deferred as null fields.
Nothing in 4.1 populates or displays them (the actual executive summary
lives in the `executiveSummary`-typed `ProposalSection`), and adding unused
fields "just in case" contradicts the same "no half-finished work" standard
as Decision 2. Milestone 4.2 can add them if the AI generator specifically
needs a quick-glance top-level summary distinct from the section itself.

**4. `ProposalStatus` is user-controlled, not auto-computed.** A proposal
starts `draft`; the only transition to `readyForReview` is an explicit
"Mark ready for review" action (enabled once every section is `approved`),
reversible via "Reopen for editing." No silent, automatic status changes —
a deliberate transparency choice: the user should always know exactly why
a status changed, mirroring how `OpportunityPipelineStage` transitions are
themselves always an explicit user action (`transitionStage`), never
inferred.

**5. Creating a proposal seeds all 8 standard `ProposalSectionType`s at
once, structured from the start** — not a blank document. This is the
single biggest lever for the "Notion/Loop, not Word" brief: a new proposal
is immediately a legible checklist of what's needed, not an intimidating
blank page. This scaffolding + pipeline-stage bridging
(`OpportunityService.transitionStage` to `proposalStarted`, guarded so it
never regresses a stage that's already further along) are orchestrated in
the screen's controller, not inside `ProposalService` — creating a
proposal-with-sections isn't a strict cross-collection invariant the way
an `OpportunityEvent` audit entry is (Decision 6 explains why that one
case *does* get a service-level batch); a partially-scaffolded proposal
if something fails mid-loop is a recoverable, low-stakes edge case (the
user can just add the missing section via "Add section"), not worth an
atomic batch across two services.

**6. Sections expand in place — no separate editor screen, no explicit
Save button.** Collapsed, a section is one glanceable row (icon, title,
status chip, one-line preview); tapping expands it inline to an editable
title + multi-line content field. Every edit auto-commits on a short
debounce and immediately on blur (`FocusNode` listeners flush pending
edits) — the same "it just saves" feel as Notion/Google Docs, directly
implementing "reduce cognitive load... avoid long forms." The proposal
title is inline tap-to-edit for the same reason. This is a genuinely new
interaction pattern for this codebase (every prior "edit" flow pushes a
separate form screen); it's introduced here because the brief explicitly
asked for this app's first screen to depart from that shape.

**7. Reordering uses `ReorderableListView.builder`'s `header`/`footer`
slots** (a progress-ring header above the list, an "Add section" footer
below it) rather than a separate `CustomScrollView`/`SliverReorderableList`
composition — simpler, and this Flutter version supports it directly.
Uses the current `onReorderItem` callback, not the deprecated `onReorder`
(which required a manual off-by-one adjustment `onReorderItem` already
does internally).

**8. `ProposalProgressRing` and the section-status color mapping
(`proposal_section_style.dart`) are both new, small, reusable files** —
mirroring the `priority_style.dart` extraction from Milestone 3.7 exactly
(a plain `Chip`/`CircularProgressIndicator`, never a bespoke gauge widget,
consistent with ADR-004/005's stance on percentage/status visuals).
`ProposalSectionStatus.approved` reuses `colorScheme.primaryContainer`
(this app's own green seed color) as its "done" signal rather than
inventing a new color.

**9. Entry point: a 6th per-opportunity action button on the Opportunities
screen**, exactly as the Phase 4 plan flagged. This is the point that row
should stop growing — restated below, not fixed here.

## Alternatives Considered

- **Embedding sections as an array field on `Proposal`.** Rejected per
  Decision 1 — violates this project's explicit "never embed entire
  objects" rule and would block 4.2's per-section regeneration.
- **Shipping the full 4-value `ProposalStatus`/`ProposalSectionStatus`
  enums from the Phase 4 sketch now.** Rejected per Decision 2 — would
  leave unreachable states this milestone, which this project's own "no
  half-finished implementations" standard argues against.
- **A separate full-screen editor per section** (matching the older
  classification-screen shape). Rejected per Decision 6 — directly
  contradicts the "modern workspace, not Word" brief.
- **An explicit "Save" button per section.** Rejected — auto-save-on-edit
  is table stakes for the Notion/Loop comparison the brief named
  explicitly.
- **A `createWithStandardSections` batch method on `ProposalService`
  spanning both collections.** Considered for atomicity, rejected per
  Decision 5 — the coupling isn't a strict invariant the way
  `OpportunityEvent` creation is, and keeping each service scoped to
  exactly one collection stays consistent with every other service in this
  app.

## Consequences

- New Firestore collections `proposals`/`proposalSections`, each with the
  same blanket `allow read, write: if isAuthenticated()` rule as every
  other collection — no new rule shape.
- One new composite index (`proposalSections`: `proposalId` ASC, `order`
  ASC) — filtering and ordering on different fields, same reasoning as the
  existing `opportunityEvents` index.
- No Cloud Functions touched this milestone — nothing to deploy there.
- `firebase_storage` remains an unused dependency (Document Library,
  Milestone 4.3, is what will finally configure it).
- A proposal's creation and its pipeline-stage bridge are two separate
  Firestore operations, not one atomic transaction (Decision 5) — an
  accepted, low-stakes tradeoff for simplicity.

## Architectural Recommendations

- **Six per-opportunity action buttons is the point to stop adding more** —
  restated from the Phase 4 plan, now actually reached. Classification/
  Pipeline/Match Analysis/Strategic Review/Proposal already fill one `Wrap`
  row on the Opportunities screen. Milestone 4.2 should not add a 7th;
  instead, this row should be consolidated into a single "AI Insights" (or
  similar) menu/bottom sheet before anything else is added to it.
- **The inline-expand-and-auto-save editing pattern introduced here
  (`ProposalSectionCard`, `_ProposalTitleField`) is new to this codebase.**
  If a future milestone wants this same feel elsewhere (e.g. editing a
  Knowledge Article), consider factoring the "tap-to-edit text with
  debounced auto-save" behavior into a small reusable widget rather than
  re-implementing the `TextEditingController`/`FocusNode`/`Timer` plumbing
  a third time.
- **`ProposalStatus`/`ProposalSectionStatus` will both grow one value each
  in upcoming milestones** (`finalized` in 4.4, `aiDrafted` in 4.2) — safe,
  additive changes per Decision 2, but worth remembering these two enums
  aren't "done" yet when those milestones start.
- **Proposal section content is plain text**, consistent with every other
  long-form text field in this app, but — as the Phase 4 plan already
  flagged — this is the one place in the app where real formatting will
  eventually matter for a client-facing deliverable.
