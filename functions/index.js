"use strict";

const {onSchedule} = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

const REQUIREMENTS_COLLECTION = "requirements";
const STATUS_PENDING = "pending";
const STATUS_REJECTED = "rejected";
const REJECTION_REASON_TIMEOUT = "approval_timeout";
const PAGE_SIZE = 200;
const FIFTEEN_DAYS_MS = 15 * 24 * 60 * 60 * 1000;

function normalizedString(value) {
  return typeof value === "string" ? value.trim().toLowerCase() : "";
}

function asTimestamp(value) {
  if (value instanceof admin.firestore.Timestamp) {
    return value;
  }

  if (
    value &&
    typeof value.toDate === "function" &&
    typeof value.toMillis === "function"
  ) {
    return value;
  }

  return null;
}

function hasApprovalMetadata(data) {
  const approvedBy = typeof data.approvedBy === "string"
    ? data.approvedBy.trim()
    : "";

  return approvedBy.length > 0 || asTimestamp(data.approvedAt) !== null;
}

async function rejectIfRequirementIsStillStale(requirementRef, cutoffMillis) {
  return db.runTransaction(async (transaction) => {
    const requirementSnapshot = await transaction.get(requirementRef);
    if (!requirementSnapshot.exists) {
      return "missing";
    }

    const data = requirementSnapshot.data() || {};
    if (normalizedString(data.status) !== STATUS_PENDING) {
      return "statusChanged";
    }

    if (hasApprovalMetadata(data)) {
      return "statusChanged";
    }

    const createdAt = asTimestamp(data.createdAt);
    if (!createdAt) {
      return "invalidTimestamp";
    }

    if (createdAt.toMillis() > cutoffMillis) {
      return "notOldEnough";
    }

    transaction.update(requirementRef, {
      status: STATUS_REJECTED,
      rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
      rejectionReason: REJECTION_REASON_TIMEOUT,
      autoRejected: true,
    });

    return "rejected";
  });
}

exports.autoRejectStaleRequirements = onSchedule(
  {
    schedule: "0 1 * * *",
    timeZone: "Asia/Kolkata",
  },
  async () => {
    const cutoffMillis = Date.now() - FIFTEEN_DAYS_MS;
    const cutoffTimestamp = admin.firestore.Timestamp.fromMillis(cutoffMillis);

    logger.info("Starting stale requirement auto-rejection run.", {
      collection: REQUIREMENTS_COLLECTION,
      cutoff: cutoffTimestamp.toDate().toISOString(),
      pageSize: PAGE_SIZE,
    });

    const baseQuery = db
      .collection(REQUIREMENTS_COLLECTION)
      .where("status", "==", STATUS_PENDING)
      .where("createdAt", "<=", cutoffTimestamp)
      .orderBy("createdAt", "asc");

    let totalCandidates = 0;
    let autoRejected = 0;
    let skippedStatusChanged = 0;
    let skippedInvalidTimestamp = 0;
    let skippedNotOldEnough = 0;
    let skippedMissing = 0;
    let errorCount = 0;
    let lastVisible = null;

    while (true) {
      let query = baseQuery.limit(PAGE_SIZE);
      if (lastVisible) {
        query = query.startAfter(lastVisible);
      }

      const snapshot = await query.get();
      if (snapshot.empty) {
        break;
      }

      totalCandidates += snapshot.size;

      for (const requirementDoc of snapshot.docs) {
        try {
          const outcome = await rejectIfRequirementIsStillStale(
            requirementDoc.ref,
            cutoffMillis,
          );

          switch (outcome) {
            case "rejected":
              autoRejected++;
              break;
            case "statusChanged":
              skippedStatusChanged++;
              break;
            case "invalidTimestamp":
              skippedInvalidTimestamp++;
              logger.warn(
                "Skipped stale requirement auto-rejection due to missing or invalid createdAt.",
                {
                  path: requirementDoc.ref.path,
                },
              );
              break;
            case "notOldEnough":
              skippedNotOldEnough++;
              break;
            case "missing":
              skippedMissing++;
              break;
            default:
              errorCount++;
              logger.error("Unexpected stale requirement outcome.", {
                path: requirementDoc.ref.path,
                outcome,
              });
          }
        } catch (error) {
          errorCount++;
          logger.error("Failed to auto-reject stale requirement.", {
            path: requirementDoc.ref.path,
            error: error instanceof Error ? error.message : String(error),
          });
        }
      }

      lastVisible = snapshot.docs[snapshot.docs.length - 1];
      if (snapshot.size < PAGE_SIZE) {
        break;
      }
    }

    logger.info("Completed stale requirement auto-rejection run.", {
      collection: REQUIREMENTS_COLLECTION,
      cutoff: cutoffTimestamp.toDate().toISOString(),
      totalCandidates,
      autoRejected,
      skippedStatusChanged,
      skippedInvalidTimestamp,
      skippedNotOldEnough,
      skippedMissing,
      errorCount,
    });
  },
);
