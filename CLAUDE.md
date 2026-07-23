## Project Overview
- Name: jva_projecttracker
- Stack: Flutter (Dart), Firebase (Firestore, Auth, Cloud Functions on Vertex AI)
- Target Platforms: Android, Web, iOS
- Purpose: Internal JVA tool to track past/running/planned projects, catalogue
  company-built applications, and auto-discover + AI-score contract/tender
  opportunities against the company's profile. Sibling project to `coffeecore`,
  lives in the same `JVA Projects/` parent folder but is a fully separate app.

## Build & Quality Commands
- Check Code / Linting: `flutter analyze`
- Run Tests: `flutter test`
- Format Code: `dart format .`
- Clean Build: `flutter clean && flutter pub get`
- Deploy functions: `cd functions && npm install && cd .. && firebase deploy --only functions`

## Architecture
- Folder structure is layer-first, same convention as coffeecore:
  - `lib/models/` — `Project`, `CompanyApplication`, `Contract` (Firestore-backed,
    each with `fromMap`/`toMap` and a status enum + `label` extension)
  - `lib/screens/` — one subfolder per feature (`dashboard`, `projects`,
    `applications`, `contracts`, `shared`); `shared/home_shell.dart` is the bottom-nav
    app shell
  - `lib/services/` — one Firestore service per collection (`ProjectService`,
    `ApplicationService`, `ContractService`) + `providers.dart` (Riverpod
    `StreamProvider`s wrapping each service's `watchAll()`)
  - `functions/` — Node.js Cloud Functions (Firebase Functions v2), not Dart
- State management: `flutter_riverpod` (no code generation — providers are hand-written
  in `services/providers.dart`, not `@riverpod` annotated)

## Cloud Functions (functions/index.js)
Two AI-powered callables, both using `@google/genai` against **Vertex AI** (not the
public Gemini API) with the `googleSearch` grounding tool — this is what gives the
app live web-search capability without a separate search API key:

- `discoverApplicationAreas({name, description})` → `{areas: string[]}` — called from
  the Application form's "Discover" button.
- `searchContracts({query?})` → `{created: number}` — called from the Contracts tab's
  search icon. Builds a "company profile" string from all `projects` + `applications`
  docs, asks Gemini to find real open contracts/tenders via search and score each
  0–100 for fit, then writes new ones into `contracts` (deduped by `sourceUrl`).
- `scheduledContractDiscovery` — same logic as `searchContracts`, runs automatically
  every Monday 08:00 via Cloud Scheduler.

Model responses are parsed as raw JSON extracted from the text response (`extractJson`
helper) rather than via `responseSchema`, because grounding tools and strict schema
enforcement don't reliably combine — if the model changes and this becomes safe to
change, it would simplify the parsing.

## Coding Conventions
(same as coffeecore)
- Prefer early returns to minimize deep widget/code nesting.
- Always implement `const` constructors on UI widgets where applicable.
- Do not leave manual print statements; use `developer.log()` / the `logger` package.
- Use explicit types rather than relying heavily on `var` or `dynamic`.

## Deployment & Verification Rules
- Before concluding any task, run `flutter analyze` to guarantee zero errors or warnings.
- Run `dart format .` on any updated or newly created Dart file.

## Current State / Pending Work
- **Not yet wired to a real Firebase project.** `lib/firebase_options.dart` is a
  placeholder (`REPLACE_ME` values) — see `FIREBASE_SETUP.md` for the full manual
  setup checklist (create Firebase project, enable Blaze billing + `aiplatform.googleapis.com`,
  `flutterfire configure`, deploy rules/functions). These steps require interactive
  Google login/billing console access, so they were left for the user to run.
- Firestore security rules (`firestore.rules`) currently just require
  `request.auth != null` on all three collections — no role separation yet. Fine for
  a small internal team; revisit if this grows.
- No auth screen/flow has been built yet in the Flutter app itself — Firebase Auth is
  enabled as a dependency but there's no sign-in UI. Whoever picks this up next should
  decide on a sign-in method (Email/Password is simplest) before the app is usable
  beyond local emulation.
- No tests exist yet (`test/widget_test.dart` was removed as it was the unmodified
  counter-app template and no longer matched the app).
