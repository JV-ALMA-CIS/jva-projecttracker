const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { notifyAllUsers } = require("./matchScorePushNotification");

/**
 * "Share with team": anyone in the office who spots an opportunity — or
 * adds one by hand — can bring it to everyone's attention in one tap.
 * Pushes to every other person's devices and records the share in
 * `teamShares` so it also appears in everyone's Notifications tab.
 *
 * Shares admin initialization with index.js (do not call initializeApp).
 */

const MAX_NOTE_LENGTH = 280;

/**
 * Who is sharing, as colleagues know them: the name they set in Settings
 * (their login display name), else the part of their email before the @.
 */
function sharerName(token) {
  const name = typeof token?.name === "string" ? token.name.trim() : "";
  if (name) return name;
  const email = typeof token?.email === "string" ? token.email : "";
  const local = email.split("@")[0] || "";
  return local ? local.charAt(0).toUpperCase() + local.slice(1) : "A colleague";
}

function cleanNote(note) {
  if (typeof note !== "string") return "";
  return note.replace(/\s+/g, " ").trim().slice(0, MAX_NOTE_LENGTH);
}

/**
 * Core of the callable, with dependencies injected for tests.
 * Returns `{ shareId, recipients }`.
 */
async function shareOpportunity({ db, auth, data, notify = notifyAllUsers, now = new Date() }) {
  if (!auth) throw new HttpsError("unauthenticated", "Sign in to share with the team");
  const opportunityId = typeof data?.opportunityId === "string" ? data.opportunityId : "";
  if (!opportunityId) throw new HttpsError("invalid-argument", "opportunityId is required");

  const snap = await db.collection("opportunities").doc(opportunityId).get();
  if (!snap.exists) throw new HttpsError("not-found", "Opportunity not found");
  const opportunity = snap.data();

  const sharedByName = sharerName(auth.token);
  const note = cleanNote(data.note);
  const added = data?.justAdded === true;

  const ref = await db.collection("teamShares").add({
    opportunityId,
    opportunityTitle: opportunity.title || "",
    kind: opportunity.kind || "tender",
    sharedByUid: auth.uid,
    sharedByName,
    note,
    justAdded: added,
    createdAt: admin.firestore.Timestamp.fromDate(now),
  });

  const result = await notify(
    {
      type: "teamShare",
      opportunityId,
      opportunityTitle: opportunity.title,
      kind: opportunity.kind,
      sharedByName,
      note,
      justAdded: added,
    },
    { excludeUid: auth.uid },
  );
  return { shareId: ref.id, recipients: result?.successCount ?? 0 };
}

/** Callable: shareOpportunityWithTeam — { opportunityId, note?, justAdded? } */
const shareOpportunityWithTeam = onCall(async (request) =>
  shareOpportunity({ db: admin.firestore(), auth: request.auth, data: request.data }),
);

module.exports = { shareOpportunityWithTeam, shareOpportunity, sharerName, cleanNote };
