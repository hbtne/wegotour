const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");

const db = admin.firestore();

// ==========================================
// SEND NOTIFICATION (ADMIN SDK v13 SAFE VERSION)
// ==========================================
async function sendNotification(userId, title, body, data = {}) {
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
        title,
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
      title,
      body,
    },
    data: {
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

  return sendNotification(
    ownerId,
    "Có bình luận mới",
    `${comment.username} đã bình luận bài viết của bạn`,
    {
      type: "comment",
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

  if (beforeCount === afterCount) {
    logger.info("Likes did not change, skipping");
    return null;
  }

  return sendNotification(
    after.authorId,
    "Có lượt thích mới",
    "Bài viết của bạn vừa có người thích",
    {
      type: "like",
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
      "Sự kiện mới",
      `${data.title} vừa được tạo trong nhóm`,
      {
        type: "event",
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
  const date = today.getDate();

  const postsSnap = await db.collection("posts").get();

  const promises = [];

  postsSnap.forEach((doc) => {
    const post = doc.data();
    const createdAt = post.createdAt?.toDate();

    if (!createdAt) return;
    if (createdAt.getMonth() !== month || createdAt.getDate() !== date) return;

    const userId = post.authorId;
    if (!userId) return;

    promises.push(
      sendNotification(
        userId,
        "Kỷ niệm hôm nay",
        `Một bài viết của bạn từ năm trước đang xuất hiện lại.`,
        {
          type: "anniversary",
          postId: doc.id,
        }
      )
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