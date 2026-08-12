# ADR-002 — Opportunity Pipeline

## Status
Accepted (Milestone 3.2)

## Context
Milestone 3.1 added AI-classification fields to `Opportunity` (status/
confidence/risk/priority/knowledge-graph links), all manually edited for now
ahead of a future AI pass. Milestone 3.2 adds the *workflow* layer on top:
a detailed pipeline stage, an assignment/notes surface, and an auditable
history of every stage transition. As with 3.1, this is explicitly workflow
only — no AI, no Cloud Functions, no proposal generation.

Several concrete decisions had to be made that the milestone brief didn't
fully specify.

## Decision

**1. `pipelineStage` is a new, separate field from the existing `status`.**
`OpportunityStatus` (discovered/reviewing/applied/won/lost/dismissed) is a
simple 6-value field the existing Cloud Function and list-screen dropdown
already read/write. `OpportunityPipelineStage` is a 14-value, much more
granular workflow tracker. Both now coexist on the same `Opportunity`
document. This is a **known duplication of concept** — flagged as an
architectural recommendation below rather than resolved here, since
reconciling them (e.g. deriving one from the other) is a product decision
this milestone was not asked to make, and doing so would risk breaking the
existing Cloud Function's contract with `status`.

**2. `OpportunityPipelineStage`, not `PipelineStage`, is the enum's actual
name.** `cloud_firestore` (v6.x) ships its own Pipeline-query API with a
top-level `PipelineStage` type. A file that imports both `cloud_firestore`
and a same-named domain enum hits a genuine ambiguous-import compile error
the moment it references the name unqualified — this surfaced immediately
while writing `opportunity_event.dart`. Rather than adding `hide
PipelineStage` to every `cloud_firestore` import across the model/service
layer (fragile — easy to forget in a future file), the enum itself was
renamed once, early, before more code was built on top of it.

**3. `assignedTo` is free text, not a picker sourced from live user data.**
`firestore.rules` restricts the `users` collection to `request.auth.uid ==
userId || isAdmin()` — a regular staff account cannot list or read anyone
else's profile, and `UserService` has no `watchAll()`. Building a proper
"assign to a staff member" picker would require loosening that rule, which
is an auth/security-module change outside a pipeline-workflow milestone.
`assignedTo` is therefore a plain `String?` text field today; a future
milestone that revisits `users` collection read access could upgrade it to
a real picker without changing the field's shape.

**4. Every stage transition is a single atomic Firestore batch write**
(`OpportunityService.transitionStage`): it updates
`pipelineStage`/`lastStageUpdated`/`updatedAt` on the opportunity **and**
appends the corresponding `OpportunityEvent`, in one `WriteBatch.commit()`.
This guarantees the two can never disagree — there is no window where an
opportunity's stage has changed but no event explains why, or vice versa.
`fromStage` is read fresh from the opportunity document at the start of
`transitionStage` (not passed in by the caller), so it's always accurate
even if the UI's cached copy is stale.

**5. `opportunityEvents` is append-only at the rules level.** `allow read,
create: if isAuthenticated(); allow update, delete: if false;` — matching
the collection's purpose as a factual audit log. This is a **new pattern**
for this codebase (every other collection allows full `read, write`); it's
the first collection where mutation-after-creation is actively wrong by
design, not just unsupported by the UI.

**6. Event `title` is generated in English by the service, not localized.**
Every service in this app is a pure Firestore-access layer with zero
dependency on `AppStrings` — `transitionStage` follows that same rule, so
`title: 'Stage changed to ${newStage.label}'` uses the enum's own English
`.label`. Only the UI layer (`OpportunityTimeline`, `app_strings.dart`'s
`pipelineStageLabel`) is locale-aware. This means a stored event's title is
permanently in English regardless of which locale was active when it was
created — acceptable for now since these are internal audit records, not
end-user-facing content in the way opportunity descriptions are.

**7. A dedicated `OpportunityPipelineScreen`**, separate from Milestone
3.1's `OpportunityClassificationScreen`, reached via its own "Pipeline"
action on the opportunity tile. Classification (AI-scoring fields) and
pipeline (workflow fields) are different concerns edited at different
times by (likely) different people; keeping them as separate push-screens
matches the one-concern-per-screen pattern used throughout this app rather
than growing the classification screen further.

**8. `pipelineStageColor`/`PipelineStageBadge` were extracted into a shared
widget** (`lib/widgets/pipeline_stage_badge.dart`) rather than duplicated
between the list tile's `Chip` and the pipeline screen's standalone
indicator, so the two views' stage-to-color mapping can't drift apart —
mirroring `fit_score_badge.dart`'s existing role as the one color function
for its concept.

## Alternatives Considered

- **Merge `status` and `pipelineStage` into one field.** Rejected — would
  require rewriting the Cloud Function's `status: "discovered"` write and
  the existing status dropdown, both out of scope for a workflow-only
  milestone, and risks losing the simpler field external integrations may
  come to depend on.
- **A `usersStreamProvider` + `RelationshipPicker<UserProfile>` for
  `assignedTo`.** Rejected for this milestone — blocked on a
  `firestore.rules` change to the `users` collection that's a distinct,
  security-relevant decision belonging to its own review, not something to
  fold into a pipeline-workflow change.
- **Separate, non-atomic writes** (update the opportunity, then separately
  create the event). Rejected — a crash or dropped connection between the
  two writes would leave the opportunity's stage unexplained by any event,
  defeating the point of an audit trail. A single batch removes that window
  entirely.
- **Inlining pipeline editing into `OpportunityClassificationScreen`.**
  Rejected in favor of a separate `OpportunityPipelineScreen` — see
  Decision 7.

## Consequences

- No Firestore migration needed for existing opportunities: every new field
  defaults safely (`pipelineStage` defaults to `discovered`, matching
  `status`'s existing default), confirmed by a model test that round-trips
  a map shaped exactly like a pre-Milestone-3.2 document.
- `opportunityEvents` requires both a new `firestore.rules` match block and
  a new composite index (`opportunityId` ASC + `createdAt` DESC) —
  deployment details below.
- Two **real, pre-existing bugs** were found and fixed while building and
  testing this milestone (not scope creep — both block the feature from
  working correctly):
  - `intl`'s `DateFormat.yMMMd(<locale>)` throws `LocaleDataException`
    unless `initializeDateFormatting()` has been called first. Nothing in
    `main.dart` ever called it, so **the Experience form's date pickers
    (Milestone 2.7) have been broken at runtime since they were built** —
    this was invisible until a widget test actually pumped a screen that
    calls `DateFormat.yMMMd` with an explicit locale. Fixed by initializing
    both supported locales (`en`, `it`) once in `main()`.
  - Adding a third action button to the opportunity tile's action row
    caused a `RenderFlex` overflow on narrower widths. Fixed by converting
    that `Row` (with a `Spacer`) to a `Wrap`, matching the pattern already
    used for the tile's status chips.
- `OpportunityService` now depends on `OpportunityEventService`'s
  collection name constant (`kOpportunityEventsCollection`) to keep the
  batch write's target in sync with `OpportunityEventService.watchByOpportunity`'s
  target — a light coupling between two services, which is otherwise
  avoided everywhere else in this codebase (every other service is
  fully self-contained). Documented here rather than hidden, since it's the
  one deliberate exception to that rule.
