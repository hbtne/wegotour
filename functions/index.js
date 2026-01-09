const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const logger = functions.logger;
const db = admin.firestore();

// ==========================================
// SEND NOTIFICATION (ADMIN SDK v13 SAFE VERSION)
// ==========================================
async function sendNotification(userId, body, type, data = {}) {
  logger.info("sendNotification called", { userId, data });

  if (!userId) {
    logger.error("Missing userId");
    return null;
  }

  // Save notification to Firestore (in-app notification)
  try {
    await db
      .collection("users")
      .doc(userId)
      .collection("notifications")
      .add({
        type,
        body,
        data,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        read: false,
      });

    logger.info("Saved notification to Firestore for user:", userId);
  } catch (err) {
    logger.error("Failed to write notification:", err);
  }

  // Fetch FCM token
  const userSnap = await db.collection("users").doc(userId).get();
  if (!userSnap.exists) {
    logger.error("User does not exist:", userId);
    return null;
  }

  const token = userSnap.data().fcmToken;
  if (!token) {
    logger.warn("User has no FCM token:", userId);
    return null;
  }

  // Payload format using admin.messaging().send (v13)
  const message = {
    token,
    notification: {
      body,
    },
    data: {
      type,
      ...data,
    },
  };

  try {
    const res = await admin.messaging().send(message);
    logger.info("FCM sent to", userId, res);
    return res;
  } catch (err) {
    logger.error("FCM send error:", err);
    return null;
  }
}

async function awardBadgeDocs(eventId, badge, leaderboardSnap) {
  const batch = db.batch();
  const baseBadge = {
    id: badge.id,
    name: badge.name || 'Huy hiệu sự kiện',
    icon: badge.icon || '',
    earnedAt: admin.firestore.FieldValue.serverTimestamp(),
    fromEvent: eventId,
    totalScoreAtAward: undefined,
  };

  leaderboardSnap.docs.forEach((doc) => {
    const userId = doc.id;
    const score = doc.get('totalScore') || 0;
    const userBadgeRef = db
      .collection('users')
      .doc(userId)
      .collection('badges')
      .doc(`${eventId}_${badge.id}`);

    const badgeDoc = { ...baseBadge, totalScoreAtAward: score };
    batch.set(userBadgeRef, badgeDoc, { merge: true });
  });

  await batch.commit();
}

// ==========================================
// COMMENT TRIGGER
// ==========================================
exports.onNewComment = onDocumentCreated("comments/{commentId}", async (event) => {
  logger.info("onNewComment triggered", event.params);

  const comment = event.data.data();
  const postId = comment.post;

  const postSnap = await db.collection("posts").doc(postId).get();
  if (!postSnap.exists) {
    logger.error("Post not found:", postId);
    return null;
  }

  const ownerId = postSnap.data().authorId;

  if(comment.userId == ownerId)
  return null;

  return sendNotification(
    ownerId,
    `${comment.username} đã bình luận bài viết của bạn`,
    "communications",
    {
      postId,
      commentId: event.params.commentId,
    }
  );
});

// ==========================================
// LIKE TRIGGER
// ==========================================
exports.onPostLike = onDocumentUpdated("posts/{postId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();

  const beforeCount = (before.likes || []).length;
  const afterCount = (after.likes || []).length;

  if (afterCount <= beforeCount) {
    logger.info("Unlike or no change, skipping");
    return null;
  }

const userLikedId = after.likedBy[after.likedBy.length - 1];

  if(userLikedId === after.authorId)
  return null;

  const userSnap = await db.collection("users").doc(userLikedId).get();
  if (!userSnap.exists) {
    logger.error("User not found:", userLikedId);
    return null;
  }

  const username = userSnap.data().username;

  const message =
    afterCount > 1
      ? `${username} và ${afterCount - 1} người khác đã bày tỏ cảm xúc về bài viết của bạn.`
      : `${username} đã bày tỏ cảm xúc về bài viết của bạn.`;

  return sendNotification(
    after.authorId,
    message,
    "communications",
    {
      postId: event.params.postId,
    }
  );
});

// ==========================================
// EVENT CREATED
// ==========================================
exports.onEventCreated = onDocumentCreated("events/{eventId}", async (event) => {
  const data = event.data?.data();
  if (!data) {
    logger.error("Event data missing");
    return null;
  }

  const createdByUserId = data.createdBy?.id;
  const groupId = data.groupId;

  if (!groupId) {
    logger.error("Event missing groupId");
    return null;
  }

  const groupSnap = await db.collection("groups").doc(groupId).get();
  if (!groupSnap.exists) {
    logger.error("Group not found:", groupId);
    return null;
  }

  const members = groupSnap.data().members || [];

  const promises = members.map((member) => {
    const uid = member.id;
    if (!uid) return null;
    if (uid === createdByUserId) return null;

    return sendNotification(
      uid,
      `${data.title} vừa được tạo trong nhóm ${groupSnap.data().name}`,
      "event",
      {
        eventId: event.params.eventId,
        groupId,
      }
    );
  });

  return Promise.all(promises);
});

// ==========================================
// SCHEDULED ANNIVERSARY CHECKER
// ==========================================
exports.checkAnniversary = onSchedule("every 24 hours", async () => {
  logger.info("checkAnniversary triggered");

  const today = new Date();
  const month = today.getMonth();
  const day = today.getDate();

  const postsSnap = await db.collection("posts").get();
  const promises = [];

  postsSnap.forEach((doc) => {
    const post = doc.data();
    if (!post.createdAt) return;

    const createdAt = post.createdAt.toDate();

    if (
      createdAt.getMonth() !== month ||
      createdAt.getDate() !== day
    ) return;

    const userId = post.authorId;
    if (!userId) return;

    const place = post.location ?? "một nơi nào đó";
    const formattedDate = createdAt.toLocaleDateString("vi-VN");

    const message =
      `Bạn đã đến ${place} vào ngày ${formattedDate}\n` +
      `Cùng xem lại những mảnh ký ức đó nào ❤️`;

    promises.push(
      sendNotification(
      userId,
      message,
      "anniversary",
      {
        postId: doc.id,
      })
    );
  });

  return Promise.all(promises);
});

exports.manualAwardBadges = functions.https.onCall(async (data, context) => {
  try {
    const eventId = data.eventId;

    if (!eventId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing eventId'
      );
    }

    const eventRef = db.collection('collect_events').doc(eventId);
    const eventSnap = await eventRef.get();

    if (!eventSnap.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Event not found'
      );
    }

    const eventData = eventSnap.data();
    const badge = eventData.badge;

    if (!badge || !badge.id) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Event has no badge'
      );
    }

    const leaderboardSnap = await eventRef
      .collection('leaderboard')
      .orderBy('totalScore', 'desc')
      .limit(10)
      .get();

    if (leaderboardSnap.empty) {
      throw new functions.https.HttpsError(
        'not-found',
        'No leaderboard entries'
      );
    }

    await awardBadgeDocs(eventId, badge, leaderboardSnap);
    await eventRef.update({ processed: true });

    console.log(`Awarded badge for event ${eventId} to ${leaderboardSnap.size} users.`);

    return { success: true, awarded: leaderboardSnap.size };
  } catch (error) {
    console.error('Error awarding badges:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});


exports.awardBadgesScheduled = functions.pubsub
  .schedule('every 30 minutes')
  .onRun(async () => {
    try {
      const now = admin.firestore.Timestamp.now();
      console.log(`[scheduler] Now: ${now.toDate().toISOString()}`);
      const eventsSnap = await db
        .collection('collect_events')
        .where('endAt', '<=', now)
        .where('processed', '==', false)
        .get();

      if (eventsSnap.empty) {
        console.log('[scheduler] No events to process.');
        return null;
      }

      console.log(`[scheduler] Found ${eventsSnap.size} events to process`);
      for (const eventDoc of eventsSnap.docs) {
        const eventId = eventDoc.id;
        const eventData = eventDoc.data();
        const badge = eventData.badge;
        const endAt = eventData.endAt;
        console.log(`[scheduler] Processing event ${eventId} endAt=${endAt?.toDate?.().toISOString?.() || endAt} processed=${eventData.processed}`);

        if (!badge || !badge.id) {
          console.log(`[scheduler] Event ${eventId} has no badge, marking processed.`);
          await eventDoc.ref.update({ processed: true });
          continue;
        }

        const leaderboardSnap = await eventDoc.ref
          .collection('leaderboard')
          .orderBy('totalScore', 'desc')
          .limit(10)
          .get();

        if (leaderboardSnap.empty) {
          console.log(`[scheduler] Event ${eventId} has no leaderboard, marking processed.`);
          await eventDoc.ref.update({ processed: true });
          continue;
        }

        console.log(`[scheduler] Awarding ${leaderboardSnap.size} users for event ${eventId}`);
        await awardBadgeDocs(eventId, badge, leaderboardSnap);
        await eventDoc.ref.update({ processed: true });

        console.log(`[scheduler] Awarded badge for event ${eventId} to ${leaderboardSnap.size} users.`);
      }

      return null;
    } catch (error) {
      console.error('[scheduler] Error in scheduled function:', error);
      return null;
    }
  });

const PLACE_COLLECTIONS = ["stourplace1", "food"];

function getKeys(date) {
  const y = date.getFullYear();
  const m = (date.getMonth() + 1).toString().padStart(2, "0");
  const d = date.getDate().toString().padStart(2, "0");

  return {
    dayKey: `${y}-${m}-${d}`,
    monthKey: `${y}-${m}`,
    yearKey: `${y}`,
  };
}

async function updatePlaceStats(placeId, data) {
  const tasks = PLACE_COLLECTIONS.map(col =>
    db.collection(col)
      .doc(placeId)
      .set(data, { merge: true })
  );

  return Promise.all(tasks);
}

function normalizePlaceIds(places) {
  return (Array.isArray(places) ? places : [places])
    .map(p => typeof p === "string" ? p.trim() : "")
    .filter(p => p.length > 0);
}

/**
 * ============================
 *  POST CREATED → CHECKIN COUNT
 * ============================
 */
exports.onPostCreatedStats = onDocumentCreated(
  "posts/{postId}",
  async (event) => {
    const post = event.data?.data();
    if (!post) return null;

    const createdAt =
      post.createdAt?.toDate?.() ||
      (typeof post.createdAt === "string"
        ? new Date(post.createdAt)
        : null);

    if (!createdAt) return null;

    const places = normalizePlaceIds(post.places);
    if (!places.length) return null;

    const { dayKey, monthKey, yearKey } = getKeys(createdAt);

    const tasks = PLACE_COLLECTIONS.flatMap((col) =>
      places.map(async (placeId) => {
        const ref = db.collection(col).doc(placeId);

        await db.runTransaction(async (tx) => {
          const snap = await tx.get(ref);
          if (!snap.exists) return;

          const data = snap.data() || {};
          const update = {};

          // --- Reset theo CHECKIN key ---
          if (data.checkinDayKey !== dayKey) {
            update.checkinCount = 0;
            update.checkinDayKey = dayKey;
          }

          if (data.checkinMonthKey !== monthKey) {
            update.checkinCountMonth = 0;
            update.checkinMonthKey = monthKey;
          }

          if (data.checkinYearKey !== yearKey) {
            update.checkinCountYear = 0;
            update.checkinYearKey = yearKey;
          }

          // --- Increment ---
          update.checkinCount =
            admin.firestore.FieldValue.increment(1);
          update.checkinCountMonth =
            admin.firestore.FieldValue.increment(1);
          update.checkinCountYear =
            admin.firestore.FieldValue.increment(1);

          update.latestRankingUpdate = Date.now();

          tx.set(ref, update, { merge: true });
        });
      })
    );

    await Promise.all(tasks);
    logger.info("✅ Updated checkin stats", places);
    return null;
  }
);

/**
 * ============================
 *  REVIEW CREATED → REVIEW COUNT
 * ============================
 */
exports.onReviewCreatedStats = onDocumentCreated(
  "reviews/{reviewId}",
  async (event) => {
    const review = event.data?.data();
    if (!review) return null;

    const placeId =
      typeof review.idLocation === "string"
        ? review.idLocation.trim()
        : "";

    if (!placeId) return null;

    const createdAt =
      review.createdAt?.toDate?.() ||
      (typeof review.createdAt === "string"
        ? new Date(review.createdAt)
        : null);

    if (!createdAt) return null;

    const scoreRaw = review.score;
    const score = Number.isFinite(Number(scoreRaw))
      ? Math.round(Number(scoreRaw))
      : null;

    const { dayKey, monthKey, yearKey } = getKeys(createdAt);

    const tasks = PLACE_COLLECTIONS.map(async (col) => {
      const ref = db.collection(col).doc(placeId);

      await db.runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        if (!snap.exists) return;

        const data = snap.data() || {};
        const update = {};

        // --- Reset REVIEW key ---
        if (data.reviewDayKey !== dayKey) {
          update.reviewCount = 0;
          update.ratingSum = 0;
          update.ratingCount = 0;
          update.reviewDayKey = dayKey;
        }

        if (data.reviewMonthKey !== monthKey) {
          update.reviewCountMonth = 0;
          update.ratingSumMonth = 0;
          update.ratingCountMonth = 0;
          update.reviewMonthKey = monthKey;
        }

        if (data.reviewYearKey !== yearKey) {
          update.reviewCountYear = 0;
          update.ratingSumYear = 0;
          update.ratingCountYear = 0;
          update.reviewYearKey = yearKey;
        }

        // --- Increment REVIEW ---
        update.reviewCount =
          admin.firestore.FieldValue.increment(1);
        update.reviewCountMonth =
          admin.firestore.FieldValue.increment(1);
        update.reviewCountYear =
          admin.firestore.FieldValue.increment(1);

        // --- Increment RATING (nếu hợp lệ) ---
        if (score !== null) {
          update.ratingSum =
            admin.firestore.FieldValue.increment(score);
          update.ratingSumMonth =
            admin.firestore.FieldValue.increment(score);
          update.ratingSumYear =
            admin.firestore.FieldValue.increment(score);

          update.ratingCount =
            admin.firestore.FieldValue.increment(1);
          update.ratingCountMonth =
            admin.firestore.FieldValue.increment(1);
          update.ratingCountYear =
            admin.firestore.FieldValue.increment(1);
        }

        update.latestRankingUpdate = Date.now();

        tx.set(ref, update, { merge: true });
      });
    });

    await Promise.all(tasks);
    logger.info("✅ Updated review & rating stats", placeId);
    return null;
  }
);
