const { similarTitles } = require("../funderWatchlist");

/**
 * Shared "official feed" import used by the World Bank and UNDP connectors:
 * skip items already scored (a memory collection), AI-score the rest in
 * batches, save those scoring >= [minScore] as tenders, and — when an item
 * is already in the platform (same reference or a very similar title) —
 * record its donor and, if the buyer policy had archived it as a public
 * buyer, RESTORE it instead of adding a duplicate. The first ever run
 * (empty memory) is quiet: saved items carry suppressNotification so a
 * backlog doesn't alert one by one.
 *
 * [items]: [{id, title, reference, deadline (Date), sourceUrl, buyer,
 * country, ...}]. [source]: {
 *   key, label, memoryCollection, tags, fundedBy, tenderSourceCategory,
 *   externalIdPrefix, descriptionFor(item), scoringPrompt(profile, items),
 *   restoredReason(item)
 * }.
 */
async function importScoredTenders({
  db,
  admin,
  items,
  source,
  buildProfile,
  scoreBatch,
  now = new Date(),
  logger = console,
  quiet,
  minScore = 50,
  batchSize = 60,
}) {
  const seen = new Set();
  for (let i = 0; i < items.length; i += 100) {
    const refs = items.slice(i, i + 100).map((t) => db.collection(source.memoryCollection).doc(t.id));
    if (refs.length === 0) continue;
    (await db.getAll(...refs)).forEach((snap) => {
      if (snap.exists) seen.add(snap.id);
    });
  }
  const firstRun = (await db.collection(source.memoryCollection).limit(1).get()).empty;
  const silent = quiet ?? firstRun;

  const fresh = items.filter((t) => !seen.has(t.id));
  const counts = { fetched: items.length, alreadyScored: seen.size, scored: 0, created: 0, restored: 0, quiet: silent };
  if (fresh.length === 0) {
    logger.info(`${source.key}: ${items.length} open, all already scored`);
    return counts;
  }

  const existingSnap = await db.collection("opportunities").where("kind", "==", "tender").get();
  const existing = existingSnap.docs.map((d) => ({ id: d.id, ref: d.ref, ...d.data() }));

  const profile = await buildProfile();
  const Timestamp = admin.firestore.Timestamp;
  const FieldValue = admin.firestore.FieldValue;
  const ts = Timestamp.fromDate(now);

  for (let i = 0; i < fresh.length; i += batchSize) {
    const batch = fresh.slice(i, i + batchSize);
    let results;
    try {
      results = await scoreBatch(source.scoringPrompt(profile, batch));
    } catch (e) {
      logger.error(`${source.key}: scoring batch ${i / batchSize + 1} failed`, e);
      continue;
    }
    if (!Array.isArray(results)) continue;
    counts.scored += batch.length;

    const resultByIndex = new Map(results.map((r) => [r?.index, r]));
    const remember = db.batch();
    for (const [index, t] of batch.entries()) {
      const r = resultByIndex.get(index) || {};
      const score = Math.max(0, Math.min(100, Math.round(Number(r.fitScorePercent) || 0)));
      remember.set(db.collection(source.memoryCollection).doc(t.id), { fitScorePercent: score, scoredAt: ts });

      const match = findExistingMatch(t, existing);
      if (match) {
        const update = { updatedAt: ts, [`${source.key}NoticeId`]: t.id };
        if (source.fundedBy) update.fundedBy = source.fundedBy;
        if (match.status === "archived" && match.archivedReason === "publicBuyer" && score >= minScore) {
          Object.assign(update, {
            status: "discovered",
            archivedReason: FieldValue.delete(),
            archivedReasonDetail: FieldValue.delete(),
            archivedAt: FieldValue.delete(),
            restoredReason: source.restoredReason(t),
            restoredAt: ts,
            ...(t.deadline ? { deadline: Timestamp.fromDate(t.deadline) } : {}),
          });
          counts.restored += 1;
        }
        await match.ref.update(update);
        continue;
      }
      if (score < minScore) continue;

      await db.collection("opportunities").add({
        title: t.title,
        description: source.descriptionFor(t),
        sourceUrl: t.sourceUrl,
        sourceUrlVerified: true,
        sourceUrlVerifiedAt: ts,
        sourceUrlIsFallback: false,
        client: t.buyer || source.label,
        procuringOrganization: t.buyer || null,
        tenderReferenceNumber: t.reference || null,
        deadline: t.deadline ? Timestamp.fromDate(t.deadline) : null,
        status: "discovered",
        fitScorePercent: score,
        fitReasoning: typeof r.fitReasoning === "string" ? r.fitReasoning : "",
        tags: source.tags,
        ...(source.fundedBy ? { fundedBy: source.fundedBy } : {}),
        kind: "tender",
        tenderSourceCategory: source.tenderSourceCategory,
        geographyPriority: t.country === "Kenya" ? "kenya" : "eastAfrica",
        externalId: `${source.externalIdPrefix}:${t.id}`,
        ...(silent ? { suppressNotification: true } : {}),
        discoveredAt: ts,
        updatedAt: ts,
      });
      counts.created += 1;
    }
    await remember.commit();
  }

  logger.info(
    `${source.key}: ${items.length} open, ${seen.size} already scored, ${counts.scored} scored, ` +
      `${counts.created} created, ${counts.restored} restored (fit >= ${minScore})${silent ? " [quiet]" : ""}`,
  );
  return counts;
}

/**
 * Pure: the existing opportunity (plain objects with title,
 * tenderReferenceNumber) that is this [item] — same reference number, or a
 * very similar title — or null.
 */
function findExistingMatch(item, existing) {
  const ref = String(item.reference || "").toLowerCase();
  return (
    existing.find(
      (o) =>
        (ref && String(o.tenderReferenceNumber || "").toLowerCase() === ref) ||
        similarTitles(o.title, item.title),
    ) || null
  );
}

module.exports = { importScoredTenders, findExistingMatch };
