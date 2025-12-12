const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");
admin.initializeApp();

const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");

const db = admin.firestore();

// ==========================================
// SEND NOTIFICATION
// ==========================================
async function sendNotification(userId, title, body, data = {}) {
  logger.info("sendNotification called", { userId, data });

  if (!userId) {
    logger.error("Missing userId");
    return null;
  }

  // Save notification to Firestore
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

  const payload = {
    notification: { title, body },
    data,
  };

  logger.info("Sending FCM message to:", userId);

  return admin.messaging().sendToDevice(token, payload);
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
  if (!createdByUserId) {
    logger.error("createdBy.id missing in event");
  }

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

  const groupData = groupSnap.data();
  const members = groupData.members || [];

  if (!Array.isArray(members)) {
    logger.error("Members is not an array", members);
    return null;
  }

  logger.info("Members list:", members);

  const promises = members.map((member) => {
    const uid = member.id;  // HOẶC member.userId? Cần kiểm tra trong Firestore

    if (!uid) {
      logger.error("Member has no id field:", member);
      return null;
    }

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

exports.checkAnniversary = onSchedule("every 5 minutes", async (event) => {
  const today = new Date();
  const month = today.getMonth();
  const date = today.getDate();

  const postsSnap = await db.collection("posts").get();

  const promises = [];

  postsSnap.forEach((doc) => {
    const post = doc.data();

    const createdAt = post.createdAt?.toDate();
    if (!createdAt) return;

    if (createdAt.getMonth() === month && createdAt.getDate() === date) {

      const userId = post.authorId;
      if (!userId) return;

      promises.push(
        sendNotification(
          userId,
          "Kỷ niệm hôm nay",
          `Một bài viết của bạn từ năm trước đang xuất hiện lại.`,
          {
            type: "anniversary",
            postId: doc.id
          }
        )
      );
    }
  });

  return Promise.all(promises);
});

