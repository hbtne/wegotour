import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print("✅ Firebase initialized");

  await migrateStourPlace();
}

Future<void> migrateStourPlace() async {
  await migration("stourplace1");
  await migration("food");
  print("\n🎉 Hoàn tất migration!");
}

Future<void> migration(String collectionName) async {
  final db = FirebaseFirestore.instance;
  final now = DateTime.now();

  /// ---------- 1️⃣ RESET ----------
  final allDocs = await db.collection(collectionName).get();
  final resetBatch = db.batch();

  for (final doc in allDocs.docs) {
    resetBatch.update(doc.reference, _emptyStats());
  }

  await resetBatch.commit();
  print("🧹 Reset $collectionName (${allDocs.docs.length} docs)");

  /// ---------- 2️⃣ CHECKIN từ POSTS ----------
  final posts = await db.collection('posts').get();
  final Map<String, Map<String, int>> stats = {};

  for (final post in posts.docs) {
    final data = post.data();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final places = data['places'];

    if (createdAt == null || places == null) continue;

    final List<String> placeIds = places is List
        ? places
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList()
        : (places is String && places.trim().isNotEmpty
        ? [places.trim()]
        : []);

    for (final placeId in placeIds) {
      stats.putIfAbsent(placeId, _emptyStats);

      if (_isSameDay(createdAt, now)) {
        stats[placeId]!['checkinCount'] =
            stats[placeId]!['checkinCount']! + 1;
      }

      if (_isSameMonth(createdAt, now)) {
        stats[placeId]!['checkinCountMonth'] =
            stats[placeId]!['checkinCountMonth']! + 1;
      }

      if (createdAt.year == now.year) {
        stats[placeId]!['checkinCountYear'] =
            stats[placeId]!['checkinCountYear']! + 1;
      }
    }
  }

  /// ---------- 3️⃣ REVIEW + RATING ----------
  final reviews = await db.collection('reviews').get();
  print("📝 ${reviews.docs.length} reviews");

  for (final review in reviews.docs) {
    final data = review.data();
    final placeId = (data['idLocation'] as String?)?.trim();
    final createdAt = _parseCreatedAt(data['createdAt']);
    final score = data['score'];

    if (placeId == null || placeId.isEmpty || createdAt == null) continue;

    stats.putIfAbsent(placeId, _emptyStats);

    if (_isSameDay(createdAt, now)) {
      stats[placeId]!['reviewCount'] =
          stats[placeId]!['reviewCount']! + 1;
    }

    if (_isSameMonth(createdAt, now)) {
      stats[placeId]!['reviewCountMonth'] =
          stats[placeId]!['reviewCountMonth']! + 1;
    }

    if (createdAt.year == now.year) {
      stats[placeId]!['reviewCountYear'] =
          stats[placeId]!['reviewCountYear']! + 1;
    }

    final scoreRaw = score;

    int? rating;

    if (scoreRaw is int) {
      rating = scoreRaw;
    } else if (scoreRaw is double) {
      rating = scoreRaw.round();
    } else if (scoreRaw is String) {
      rating = int.tryParse(scoreRaw);
    }

    if (rating == null) continue;

    if (_isSameDay(createdAt, now)) {
      stats[placeId]!['ratingSum'] =
          stats[placeId]!['ratingSum']! + rating;
      stats[placeId]!['ratingCount'] =
          stats[placeId]!['ratingCount']! + 1;
    }

    if (_isSameMonth(createdAt, now)) {
      stats[placeId]!['ratingSumMonth'] =
          stats[placeId]!['ratingSumMonth']! + rating;
      stats[placeId]!['ratingCountMonth'] =
          stats[placeId]!['ratingCountMonth']! + 1;
    }

    if (createdAt.year == now.year) {
      stats[placeId]!['ratingSumYear'] =
          stats[placeId]!['ratingSumYear']! + rating;
      stats[placeId]!['ratingCountYear'] =
          stats[placeId]!['ratingCountYear']! + 1;
    }
  }

  /// ---------- 4️⃣ UPDATE FIRESTORE ----------
  WriteBatch batch = db.batch();
  int updated = 0;

  for (final entry in stats.entries) {
    final placeId = entry.key.trim();
    if (placeId.isEmpty) continue;

    final ref = db.collection(collectionName).doc(placeId);
    final snap = await ref.get();
    if (!snap.exists) continue;

    batch.update(ref, entry.value);
    updated++;

    if (updated % 400 == 0) {
      await batch.commit();
      batch = db.batch();
    }
  }

  await batch.commit();
  print("✅ Updated $updated docs for $collectionName");
}

/// ===============================
/// Helpers
/// ===============================
Map<String, int> _emptyStats() => {
  'checkinCount': 0,
  'checkinCountMonth': 0,
  'checkinCountYear': 0,
  'reviewCount': 0,
  'reviewCountMonth': 0,
  'reviewCountYear': 0,
  'ratingSum': 0,
  'ratingCount': 0,
  'ratingSumMonth': 0,
  'ratingCountMonth': 0,
  'ratingSumYear': 0,
  'ratingCountYear': 0,
};

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool _isSameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

DateTime? _parseCreatedAt(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  return null;
}
