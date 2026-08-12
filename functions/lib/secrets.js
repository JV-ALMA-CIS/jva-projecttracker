const { SecretManagerServiceClient } = require("@google-cloud/secret-manager");

const client = new SecretManagerServiceClient();
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
  const [version] = await client.accessSecretVersion({
    name: `projects/${project}/secrets/${secretName}/versions/latest`,
  });
  const value = version.payload.data.toString("utf8");
  cache.set(secretName, value);
  return value;
}

module.exports = { resolveSecret };