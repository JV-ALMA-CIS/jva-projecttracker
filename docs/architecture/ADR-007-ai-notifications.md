# ADR-007 — AI Notifications

## Status
Accepted (Milestone 3.7)

## Context
Milestones 3.3-3.6 each added a distinct AI *source* of intelligence
(classification, match analysis, strategic review, portfolio
recommendations). Milestone 3.7 is the first cross-cutting feature: a
Notification Center surfacing the most important, time-sensitive signals
already present in the app — active AI recommendations (3.6) and
opportunities with an approaching deadline (Phase 1) — in one prioritized,
grouped, glanceable place. The brief was explicit that this must read as a
real notification center (prioritized, grouped, contextual actions,
meaningful empty states), not a flat list, while staying isolated to this
milestone and reusing existing services/providers/widgets wherever
possible.

## Decision

**1. Notifications are computed client-side — no new Firestore collection,
no Cloud Function changes.** Every signal a notification would report
already exists and is already live-streamed: `Recommendation.status ==
active` and `Opportunity.deadline`. A parallel `notifications` collection
would duplicate that data and require writing to it from
`generateRecommendations`/`OpportunityService.transitionStage` — both
explicitly out of scope this milestone ("keep changes isolated," "do not
redesign unrelated modules"). The brief also scopes this as an in-app
**center** (browse/triage UX), not a delivery mechanism — there's no push/
FCM infrastructure in this stack, and none was requested.

**2. Read/dismissed state is local (`SharedPreferences`), not Firestore —
mirroring `SettingsService`'s own precedent and stated reasoning
("personal display preferences, not shared business data... live in
SharedPreferences rather than the user's Firestore profile").** A
notification's read state is exactly that kind of device-local UI
preference, not shared business data multiple devices need to agree on.
`NotificationPreferencesService` stores a `Set<String>` of read IDs via
`getStringList`/`setStringList`; `NotificationReadController` (a
`Notifier<Set<String>>`) mirrors `ThemeModeController`/`AppLocaleController`
exactly — load from the service in `build()`, write through on every
mutation.

**3. `buildNotifications` is a pure, `DateTime`-injected function, not a
method on a Firestore-backed service.** Given Decision 1, there's no I/O to
wrap — the entire feature is a derivation over data the app already has
live. Making it a standalone pure function (`lib/services/
notification_builder.dart`) rather than a class keeps it trivially unit-
testable (see `test/notification_builder_test.dart`) with no Riverpod or
Firestore involved, the same testability goal every parser in this app
already serves for a different reason (validating AI JSON).

**4. `NotificationItem.priority` reuses `OpportunityPriority`** — the third
consecutive milestone to reuse this enum rather than invent an equivalent
(`Recommendation.priority` in ADR-006 was the second). Deadline urgency is
mapped onto the same three buckets (`high` at ≤2 days or overdue, `medium`
at 3-7 days) so both notification types render through one shared
priority→color mapping.

**5. `priorityColors` extracted from `recommendation_card.dart` into a new
shared `lib/widgets/priority_style.dart`**, so `NotificationTile` doesn't
duplicate that switch. This is the only change to a Milestone-3.6 file, and
it's a same-behavior extraction (identical colors, identical signature),
not a redesign of `RecommendationCard`.

**6. Two groups — "Recommendations" and "Upcoming deadlines" — not a flat
list, and not more granular sub-grouping.** This satisfies "groups related
notifications intelligently" at the level of genuine signal *kind*
(an AI opinion vs. a calendar fact) without over-engineering finer buckets
(e.g. per-category recommendation sub-groups) that the two-type dataset
doesn't yet justify. Each group is independently sorted by relevance
(recommendations arrive already priority-sorted from
`activeRecommendationsProvider`; deadlines are sorted soonest-first) and
hidden entirely when empty.

**7. "Mark all read" is the only standing button, and only renders when
there's at least one unread item.** Every other interaction is a tap on the
item itself (which marks it read and navigates) — satisfying "contextual
actions instead of excessive buttons" literally: one conditional bulk
action, zero per-row action buttons.

**8. The bell (`NotificationBellButton`) is added only to the Dashboard's
`AppBar`**, next to the existing `SettingsButton`, using Material 3's
built-in `Badge` widget for the unread count (no custom badge built).
Reasoning and the scaling gap this leaves are in Architectural
Recommendations below.

**9. A 7-day deadline window with no `low`-priority bucket.** Anything
further than 7 days out isn't yet time-sensitive enough to notify about;
everything inside the window is at least `medium`, so this feed never
carries a low-urgency deadline item — the window itself is the noise
filter, rather than adding a third priority tier that would always render
as visually de-emphasized clutter.

## Alternatives Considered

- **A `notifications` Firestore collection, written by `generateRecommendations`
  and `OpportunityService.transitionStage`.** Rejected per Decision 1 — real
  persistence and cross-device sync are a legitimate future need, but
  implementing them here would have required touching two out-of-scope
  write paths for a milestone whose brief only asked for an in-app center.
- **Storing read/dismissed state in Firestore (e.g. on the user's
  profile).** Rejected per Decision 2 — `SettingsService` already
  established that personal display/interaction preferences belong in
  `SharedPreferences`, and read-state is squarely that kind of preference.
- **A single flat, timestamp-sorted notification list.** Rejected — the
  brief explicitly said not to "simply create a list of notifications";
  grouping by signal kind (Decision 6) gives real scannability a flat feed
  wouldn't.
- **Adding the bell to all 5 primary screens' `AppBar`s in this diff.**
  Rejected for now — see Architectural Recommendations; flagged rather than
  done, to keep this milestone's footprint minimal per the brief.

## Consequences

- No Firestore schema changes, no rules/index changes, no Cloud Functions
  touched this milestone — `notificationsProvider` reads only from
  providers that already exist (`activeRecommendationsProvider`,
  `opportunitiesStreamProvider`).
- Read/dismissed state is per-device. A user switching devices (or
  reinstalling) sees every current notification as unread again — an
  accepted limitation, not a bug, matching the same limitation
  `SettingsService`'s theme/font/locale preferences already have.
- No push, email, or badge-on-app-icon delivery exists; this is purely an
  in-app, pull-based center. If the product later wants true push
  notifications, see Architectural Recommendations.
- `notificationsProvider` recomputes on every rebuild from live data — there
  is no caching/staleness concern (unlike a Firestore-backed alternative,
  which would need its own freshness story).

## Architectural Recommendations

- **The bell should eventually appear on every primary screen's `AppBar`,
  not just Dashboard's** — ideally as a follow-up pass that also finally
  makes `SettingsButton`'s placement consistent (today it's on 4 of 5
  primary screens, missing from Company Intelligence). Doing both together
  avoids two separate small, easy-to-miss diffs across the same five
  screens.
- **No true push/cross-device notifications exist.** If the product wants
  users to be alerted outside the app (mobile push, email, or even just
  "unread survives a fresh install"), that's a materially bigger lift —
  FCM/APNs setup, a server-side trigger path (most naturally added to
  `generateRecommendations` and `OpportunityService.transitionStage`, the
  same write paths this ADR deliberately avoided touching) — and deserves
  its own milestone rather than retrofitting into this one.
- **Deadline urgency thresholds (7/2 days) are hardcoded constants**
  (`kDeadlineWindowDays`/`kDeadlineHighPriorityDays` in
  `notification_builder.dart`). If these need to become user-configurable,
  they belong in `SettingsService` alongside theme/font/locale.
