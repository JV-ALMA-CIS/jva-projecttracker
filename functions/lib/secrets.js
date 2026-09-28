const { SecretManagerServiceClient } = require("@google-cloud/secret-manager");

// Built lazily (on first resolveSecret call) rather than at module load —
// the client constructor does credential/environment auto-detection
// (including a GCE metadata server probe) that can block for many seconds
// off-GCP. Since every Cloud Functions deploy loads the full index.js
// require graph just to enumerate exports (regardless of which function is
// targeted), an eager client here made `firebase deploy` hang/time out
// from any non-GCE dev machine, for every function, not just ones that
// actually use secrets.
let client;
function secretManagerClient() {
  if (!client) client = new SecretManagerServiceClient();
  return client;
}
const cache = new Map();

/**
 * Resolves a secret's current value by name, exactly the pattern already
 * used for the NuaSense API key. Never call this to read something that
 * gets stored back in Firestore — the whole point is that the raw value
 * only ever exists in memory for the duration of one request.
 *
 * Cached in-memory per Cloud Functions instance for the life of that
 * instance, so a warm instance doesn't re-hit Secret Manager on every
 * sync — matches NuaSenseService's 10-minute-cache philosophy on the
 * Dart side, adapted to "cache until this instance recycles" here since
 * secret values don't rotate on a predictable schedule.
 */
async function resolveSecret(secretName) {
  if (cache.has(secretName)) return cache.get(secretName);

  const project = process.env.GCLOUD_PROJECT;
  const [version] = await secretManagerClient().accessSecretVersion({
    name: `projects/${project}/secrets/${secretName}/versions/latest`,
  });
  const value = version.payload.data.toString("utf8");
  cache.set(secretName, value);
  return value;
}

module.exports = { resolveSecret };