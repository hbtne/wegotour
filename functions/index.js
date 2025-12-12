const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

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