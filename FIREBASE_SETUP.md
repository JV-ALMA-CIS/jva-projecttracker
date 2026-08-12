# Firebase / Google Cloud setup

This app is scaffolded but not yet wired to a real Firebase project. Follow these
steps once, from this folder (`jva_projecttracker/`).

## 1. Create the Firebase project

```
firebase login
firebase projects:create jva-projecttracker --display-name "JVA Project Tracker"
```

(Pick a different project ID if that one is taken — it must be globally unique.)

## 2. Upgrade to the Blaze (pay-as-you-go) plan

Cloud Functions calling Vertex AI, and outbound network calls in general, require
the Blaze plan. Do this in the console (billing can't be enabled via CLI):
`https://console.firebase.google.com/project/<your-project-id>/usage/details`

## 3. Enable the required Google Cloud APIs

```
gcloud config set project <your-project-id>
gcloud services enable \
  firestore.googleapis.com \
  cloudfunctions.googleapis.com \
  cloudscheduler.googleapis.com \
  cloudbuild.googleapis.com \
  aiplatform.googleapis.com \
  identitytoolkit.googleapis.com
```

`aiplatform.googleapis.com` is Vertex AI — this is what the Cloud Functions use to
call Gemini with Google Search grounding, so opportunity discovery and application-area
discovery both depend on it.

## 4. Set up Firestore and Auth

- Firestore: console → Build → Firestore Database → Create database (Native mode,
  pick a region close to your team).
- Auth: console → Build → Authentication → get started → enable at least one sign-in
  method (Email/Password is simplest for internal staff). `firestore.rules` currently
  allows read/write to any authenticated user — tighten this later if you want
  role-based access.

## 5. Point this app at the new project

```
dart pub global activate flutterfire_cli   # if not already installed
flutterfire configure
```

Select the project you just created, and the platforms you want (android, web, ios).
This overwrites the placeholder `lib/firebase_options.dart` with real config, and
registers the platform apps.

## 6. Deploy Firestore rules/indexes and Cloud Functions

```
firebase deploy --only firestore:rules,firestore:indexes
cd functions && npm install && cd ..
firebase deploy --only functions
```

## 7. Run the app

```
flutter run -d chrome   # or -d <android device id>
```

## What the two AI-powered functions do

- **`discoverApplicationAreas`** (called from the Application form's "Discover"
  button): sends the app's name/description to Gemini with Google Search grounding,
  asking for realistic real-world application areas/industries.
- **`searchOpportunities`** (called from the Opportunities tab's search icon, and also runs
  automatically every Monday via `scheduledOpportunityDiscovery`): builds a summary of
  your Firestore `projects` + `applications` as a "company profile", searches the
  web for open opportunities/tenders, and asks Gemini to score each one 0–100 for fit
  against that profile with a short justification. New opportunities are written to the
  `opportunities` collection (deduped by source URL).

Both rely on Vertex AI's Google Search grounding tool, so no separate search API key
is needed — just the `aiplatform.googleapis.com` API enabled and billing active.

## Cost notes

- Gemini calls with search grounding are billed per request/token, and grounded
  searches add a small additional per-request cost on top of normal Vertex AI Gemini
  pricing.
- The weekly scheduled function keeps this bounded automatically; the manual
  "Search now" button lets you trigger extra runs on demand.
- Watch usage under console → Vertex AI → and console → Functions → for the first
  few weeks to get a feel for actual cost before relying on it heavily.
