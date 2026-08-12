# ADR-003 — AI Opportunity Classification

## Status
Accepted (Milestone 3.3)

## Context
Milestones 3.1 and 3.2 built the *data foundation* for opportunity
intelligence (classification/knowledge-graph fields) and the pipeline
workflow (stage, notes, assignment, timeline) — both manually edited so
far. Milestone 3.3 is the first milestone to actually call Gemini for this
part of the app: given an opportunity's title/description and the full
Company Knowledge Graph (BusinessUnits, Products, Services, Capabilities,
Technologies, Industries, Experiences, Knowledge Base), classify it and
populate the Milestone 3.1 fields automatically, while leaving every field
exactly as manually editable as it already was.

This app already has an established, working pattern for Gemini
integration — `discoverApplicationAreas` and `searchOpportunities` in
`functions/index.js`, both Cloud Functions calling Gemini via Vertex AI.
The question this milestone had to answer concretely was *where the new
AI logic should live* relative to that existing boundary, and how to make
it testable given the brief's explicit "no live API calls during tests"
requirement.

## Decision

**1. The actual Gemini call stays server-side, in a new
`classifyOpportunity` Cloud Function — not in the Flutter client.**
Vertex AI is authenticated via the function's own Google Cloud
credentials (`GCLOUD_PROJECT`, no API key) — those credentials must never
reach a client app. This matches `discoverApplicationAreas` and
`searchOpportunities` exactly; nothing about this milestone's AI-call
boundary is new.

**2. Unlike the two existing callables, `classifyOpportunity` does not use
Google Search grounding.** Classification reasons over data already in
Firestore (the knowledge graph), not the live web, so no `googleSearch`
tool is attached. This means, per the existing comment in
`functions/index.js` ("grounding tools and strict schema enforcement
don't reliably combine"), structured-output mode (`responseSchema`) could
have been used reliably here — it wasn't, so this function stays
consistent with the other two callables' existing prompt-asks-for-JSON +
`extractJson` pattern rather than introducing a second Gemini output
style into the same file. Flagged below as a real future improvement.

**3. Parsing and validation happen in *two* places, independently:**
   - **Server-side** (`validateClassification` in `functions/index.js`):
     every ID field returned by Gemini is filtered down to IDs that
     actually exist in the knowledge graph snapshot just fetched — this is
     what stops a hallucinated ID from ever being written to Firestore.
     Enum fields fall back to `null` (or `needsReview` for
     `classificationStatus`) if the model returned something outside the
     allowed set.
   - **Client-side** (`parseAIClassificationResponse` in
     `ai_classification_parser.dart`): the exact same shape of validation,
     re-applied to whatever the callable actually returned over the wire.
     This is deliberate defense-in-depth, not redundancy for its own sake —
     a truncated response, a serialization quirk, or a future change to
     the Cloud Function's return shape should never be able to corrupt
     this screen's local state, even though the Cloud Function *already*
     validated the same data before writing it to Firestore.

   Both layers treat a **partial** classification as a success, not a
   failure: an ID field with some hallucinated entries mixed in keeps the
   valid ones rather than discarding the whole response; an invalid enum
   value becomes `null` rather than aborting. Only a response with no
   usable `classificationSummary` is treated as a total failure — see the
   Error Handling section below.

**4. Retry logic lives entirely server-side**
(`classifyWithRetry`, up to 3 attempts), covering API failures, timeouts
surfaced as thrown errors, and invalid/unparseable JSON alike — any of
those counts as a failed attempt and is retried the same way, with the
last error re-thrown if every attempt fails. The client does not
separately retry; it surfaces the Cloud Function's eventual success or
failure once. The callable's timeout was raised to 120s
(`{ timeoutSeconds: 120 }`) to give 3 attempts realistic room.

**5. `classificationStatus` is set to `"processing"` before the Gemini
call, and to `"classified"` or `"needsReview"` after** — never left at
whatever it was before the run. Because the classification screen watches
the opportunity live (`opportunityByIdProvider`), this means a slow
classification shows a real, Firestore-backed "Processing" state, not just
a client-side spinner. If every retry attempt fails, the opportunity is
explicitly marked `needsReview` (with `aiReviewedAt` still updated) rather
than silently reverting — `needsReview` exists in the enum specifically
for "AI touched this but couldn't confidently classify it."

**6. `AIClassificationService` accepts an `invokeOverride` callback**
(`Future<Map<String, dynamic>?> Function(String opportunityId)?`) that
completely replaces the Cloud Function call — this is what makes "mock
Gemini responses, no live API calls during tests" possible without adding
a mocking framework as a new dependency, and without needing to construct
`FirebaseFunctionsException` directly (its constructor is `@protected` in
`cloud_functions_platform_interface`, i.e. not meant to be called from
outside the plugin). This mirrors `OpportunityService`'s existing
lazily-resolved `_functionsOverride` pattern (ADR-001) one step further.

**7. AI classification and manual editing share one screen and one code
path.** Running AI just calls
`ref.read(aiClassificationServiceProvider).classifyOpportunity(id)` and
applies the parsed result to the same controllers/state the manual form
already edits — there is no separate "AI-populated, read-only" mode. This
was an explicit brief requirement ("Allow manual editing after AI
completes") and also the simplest option: the alternative (a distinct
read-only AI result view) would have meant two UIs for the same fields.

## Alternatives Considered

- **Calling Gemini directly from Flutter** (e.g. via a REST call to the
  Vertex AI API). Rejected outright — would require embedding Google Cloud
  credentials in the client, a security regression with no precedent
  anywhere in this app.
- **`responseSchema`/structured-output mode** instead of prompt-asks-for-
  JSON + `extractJson`. Considered, since this function doesn't need
  grounding and could have used it reliably. Not adopted, to keep this
  function's Gemini-call shape consistent with the two existing callables
  in the same file — introducing a second calling convention alongside the
  first, for one function, seemed like a smaller net win than the
  consistency cost. Listed below as a concrete recommendation.
- **Client-side retry** (catch a failure and re-invoke the callable
  automatically from Dart). Rejected — each retry re-fetches the entire
  knowledge graph and re-runs a Gemini call, which is naturally cheaper and
  simpler to bound (a fixed `maxAttempts`) inside a single Cloud Function
  invocation than across repeated client calls, and avoids the client
  needing its own backoff/timeout bookkeeping on top of the callable's own
  timeout.
- **Trusting the Cloud Function's output unconditionally on the client**
  (skip the second validation layer). Rejected — cheap insurance against
  exactly the "malformed AI responses fail gracefully" requirement the
  brief called out by name; the parser is pure and unit-testable, so the
  cost of keeping it is low.
- **Merging AI results into existing manually-set relationship fields**
  (union rather than replace). Rejected for this milestone — "populate
  existing Opportunity fields" reads as AI being the authority once run; a
  full replace is simpler and the fields stay manually editable
  immediately afterward if the result needs correcting.

## Consequences

- No Firestore schema change and no migration: `classifyOpportunity` only
  ever writes to fields Milestone 3.1 already added.
- No new Firestore rules or indexes are required — the callable reads
  every Company Intelligence collection and writes only to the
  `opportunities` document it was given, all already covered by existing
  rules.
- No new npm dependency was needed in `functions/` — `@google/genai` was
  already a dependency from Milestones prior to this one.
- **Cloud Function-side logic (prompt building, validation, retry) has no
  automated tests**, consistent with `discoverApplicationAreas` and
  `searchOpportunities`, neither of which have any either — this codebase
  has never had a Node/Cloud Functions test setup. This is a pre-existing
  gap, not a regression introduced here, but it means the server-side
  `validateClassification`/`classifyWithRetry` logic is only verified by
  the equivalent, thoroughly-tested Dart-side parser and manual reasoning,
  not by an automated Node test run.
- Two more real, pre-existing bugs were caught while writing this
  milestone's widget tests (same class of issue as Milestone 3.2's
  `initializeDateFormatting` finding): none new here, but the classification
  screen's own AI-timestamp display needed the same locale-initialization
  fix already applied to `main.dart` in Milestone 3.2 — confirming that fix
  was necessary, not incidental.

## Architectural Recommendations

- **Consider `responseSchema`/structured output for `classifyOpportunity`**
  specifically (not the other two callables, which still need grounding).
  Since this is the one Gemini call in the app that doesn't need Google
  Search, it's the one place structured output could be adopted with the
  least risk — worth a follow-up once there's appetite to diverge from the
  other two callables' shared style.
- **No automated Cloud Functions test coverage exists anywhere in this
  project.** If Cloud Function logic keeps growing in complexity (this
  milestone added the most Node code yet in one function), introducing a
  minimal Jest/Mocha setup for `functions/` — even just for
  `validateClassification` and `buildClassificationPrompt`, the two purest
  functions — would close a gap that's now been carried across three
  AI-integration milestones.
- **`status` vs. `pipelineStage` vs. `classificationStatus` is now three
  overlapping "where is this opportunity" fields** on one document
  (flagged for `status`/`pipelineStage` in ADR-002). `classificationStatus`
  specifically answers "has AI classified this," which is a genuinely
  distinct question from the other two, but it's worth having all three
  in view together before a fourth workflow milestone adds a fourth field
  in the same spirit.
