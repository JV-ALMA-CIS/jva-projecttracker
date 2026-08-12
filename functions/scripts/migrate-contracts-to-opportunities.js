const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Explicit project targeting: admin.initializeApp() with no args silently
// falls back to whatever ADC/GOOGLE_APPLICATION_CREDENTIALS happens to
// resolve to, which is exactly the wrong failure mode for a script that
// writes to production Firestore. Require --project (or GCLOUD_PROJECT /
// GOOGLE_CLOUD_PROJECT) so the operator always sees, in the first line of
// output, which project is about to be written to.
const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');
const projectArgIndex = args.indexOf('--project');
const projectId =
  projectArgIndex !== -1
    ? args[projectArgIndex + 1]
    : process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT;

if (!projectId) {
  console.error(
    'Refusing to run: no target project specified. Pass --project <projectId> ' +
      '(or set GCLOUD_PROJECT / GOOGLE_CLOUD_PROJECT).',
  );
  process.exit(1);
}

if (!admin.apps.length) {
  admin.initializeApp({ projectId });
}

const db = admin.firestore();

const REPORTS_DIR = path.join(__dirname, '..', 'migration-reports');

async function migrateContractsToOpportunities() {
  const startedAt = new Date();
  const startTime = Date.now();

  const sourceCollection = db.collection('contracts');
  const targetCollection = db.collection('opportunities');

  const snapshot = await sourceCollection.get();
  const total = snapshot.size;
  const summary = {
    projectId,
    dryRun,
    scanned: total,
    skipped: 0,
    copied: 0,
    errors: 0,
    skippedIds: [],
    copiedIds: [],
    errorsDetails: [],
  };

  let processed = 0;
  for (const doc of snapshot.docs) {
    processed += 1;
    process.stdout.write(`\rProcessing ${processed} / ${total}...`);

    try {
      const data = doc.data();
      const existing = await targetCollection.doc(doc.id).get();
      if (existing.exists) {
        summary.skipped += 1;
        summary.skippedIds.push(doc.id);
        continue;
      }

      if (!dryRun) {
        const payload = {
          ...data,
          updatedAt:
            data.updatedAt ?? data.discoveredAt ?? admin.firestore.FieldValue.serverTimestamp(),
        };
        await targetCollection.doc(doc.id).set(payload);
      }

      summary.copied += 1;
      summary.copiedIds.push(doc.id);
    } catch (error) {
      summary.errors += 1;
      summary.errorsDetails.push({
        id: doc.id,
        message: error.message,
        stack: error.stack ?? null,
      });
      console.error(`\n✘ Error processing document ${doc.id}:`);
      console.error(`  Message: ${error.message}`);
      if (error.stack) console.error(`  Stack: ${error.stack}`);
    }
  }
  if (total > 0) process.stdout.write('\n');

  summary.consistent =
    summary.scanned === summary.copied + summary.skipped + summary.errors;

  const durationMs = Date.now() - startTime;
  summary.startedAt = startedAt.toISOString();
  summary.durationMs = durationMs;

  return summary;
}

function writeReport(summary) {
  fs.mkdirSync(REPORTS_DIR, { recursive: true });

  const fileTimestamp = summary.startedAt.replace(/[:.]/g, '-');
  const fileName = `migration-report-${fileTimestamp}.json`;
  const filePath = path.join(REPORTS_DIR, fileName);

  const report = {
    dateTime: summary.startedAt,
    firebaseProject: summary.projectId,
    mode: summary.dryRun ? 'dry-run' : 'live',
    documentsScanned: summary.scanned,
    documentsCopied: summary.copied,
    documentsSkipped: summary.skipped,
    errors: summary.errors,
    consistent: summary.consistent,
    executionTimeMs: summary.durationMs,
    executionTimeSeconds: (summary.durationMs / 1000).toFixed(2),
    copiedIds: summary.copiedIds,
    skippedIds: summary.skippedIds,
    errorDetails: summary.errorsDetails,
  };

  fs.writeFileSync(filePath, JSON.stringify(report, null, 2));
  return filePath;
}

console.log(`Target project: ${projectId}${dryRun ? ' (DRY RUN — no writes will be made)' : ''}`);

migrateContractsToOpportunities()
  .then((summary) => {
    console.log(JSON.stringify(summary, null, 2));

    const reportPath = writeReport(summary);
    console.log(`\nReport written to: ${reportPath}`);

    if (summary.errors === 0 && summary.consistent) {
      console.log('\n✔ Migration completed successfully.');
      console.log('✔ Safe to verify opportunities collection.');
    } else {
      console.log('\n✘ Migration completed with errors — review the report before proceeding.');
    }

    process.exit(summary.errors > 0 ? 1 : 0);
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
