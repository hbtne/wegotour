import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("✅ Firebase initialized");

  await migrateStourPlace();
}

Future<void> migrateStourPlace() async {
  await migration("stourplace1");
  await migration("food");
  print("\n🎉 Hoàn tất migration!");
}

/// 🔹 Migration chính
Future<void> migration(String collectionName) async {
  final db = FirebaseFirestore.instance;
  final now = DateTime.now();

  // --- 1️⃣ Reset tất cả dữ liệu về 0 ---
  final allDocs = await db.collection(collectionName).get();
  final resetBatch = db.batch();
  for (final doc in allDocs.docs) {
    resetBatch.update(doc.reference, {
      'checkinCount': 0,
      'reviewCount': 0,
      'checkinCountMonth': 0,
      'reviewCountMonth': 0,
      'checkinCountYear': 0,
      'reviewCountYear': 0,
    });
  }
  await resetBatch.commit();
  print("🧹 Đã reset dữ liệu $collectionName (${allDocs.docs.length} doc)");

  // --- 2️⃣ Gom dữ liệu checkin từ posts ---
  final postsSnapshot = await db.collection('posts').get();
  final posts = postsSnapshot.docs;
  if (posts.isEmpty) {
    print("⚠️ Không có bài post nào");
  }

  final Map<String, Map<String, int>> stats = {}; // id -> thống kê

  for (final post in posts) {
    final data = post.data();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final places = data['places'];

    if (places == null || createdAt == null) continue;

    final placeIds = (places is List)
        ? places.whereType<String>().toList()
        : (places is String ? [places] : []);

    for (final placeId in placeIds) {
      if (placeId.trim().isEmpty) continue; // ✅ bỏ qua id rỗng

      stats.putIfAbsent(placeId, () => {
        'checkinCount': 0,
        'checkinCountMonth': 0,
        'checkinCountYear': 0,
        'reviewCount': 0,
        'reviewCountMonth': 0,
        'reviewCountYear': 0,
      });

      // Cộng checkin
      if (createdAt.year == now.year &&
          createdAt.month == now.month &&
          createdAt.day == now.day) {
        stats[placeId]!['checkinCount'] =
            (stats[placeId]!['checkinCount'] ?? 0) + 1;
      }

      if (createdAt.year == now.year && createdAt.month == now.month) {
        stats[placeId]!['checkinCountMonth'] =
            (stats[placeId]!['checkinCountMonth'] ?? 0) + 1;
      }

      if (createdAt.year == now.year) {
        stats[placeId]!['checkinCountYear'] =
            (stats[placeId]!['checkinCountYear'] ?? 0) + 1;
      }
    }
  }

  // --- 3️⃣ Gom dữ liệu review từ "reviews" ---
  final reviewsSnapshot = await db.collection('reviews').get();
  final reviews = reviewsSnapshot.docs;
  print("📝 Tìm thấy ${reviews.length} review");

  for (final review in reviews) {
    final data = review.data();
    final idLocation = data['idLocation'] as String?;
    final createdAt = _parseCreatedAt(data['createdAt']);

    if (idLocation == null || idLocation.trim().isEmpty || createdAt == null)
      continue;

    stats.putIfAbsent(idLocation, () => {
      'checkinCount': stats[idLocation]?['checkinCount'] ?? 0,
      'checkinCountMonth': stats[idLocation]?['checkinCount'] ?? 0,
      'checkinCountYear': stats[idLocation]?['checkinCount'] ?? 0,
      'reviewCount': 0,
      'reviewCountMonth': 0,
      'reviewCountYear': 0,
    });

    // Cộng review
    if (createdAt.year == now.year &&
        createdAt.month == now.month &&
        createdAt.day == now.day) {
      stats[idLocation]!['reviewCount'] =
          (stats[idLocation]!['reviewCount'] ?? 0) + 1;
    }

    if (createdAt.year == now.year && createdAt.month == now.month) {
      stats[idLocation]!['reviewCountMonth'] =
          (stats[idLocation]!['reviewCountMonth'] ?? 0) + 1;
    }

    if (createdAt.year == now.year) {
      stats[idLocation]!['reviewCountYear'] =
          (stats[idLocation]!['reviewCountYear'] ?? 0) + 1;
    }
  }

  // --- 4️⃣ Cập nhật Firestore ---
  int updatedCount = 0;
  WriteBatch batch = db.batch();

  for (final entry in stats.entries) {
    final placeId = entry.key;
    if (placeId.trim().isEmpty) {
      print("⚠️ Bỏ qua placeId rỗng");
      continue;
    }

    final placeRef = db.collection(collectionName).doc(placeId);
    final doc = await placeRef.get();
    if (!doc.exists) {
      print("⚠️ Bỏ qua $placeId (không có trong $collectionName)");
      continue;
    }

    batch.update(placeRef, entry.value);
    updatedCount++;

    // Commit trung gian
    if (updatedCount % 400 == 0) {
      await batch.commit();
      print("💾 Đã commit batch trung gian ($updatedCount)");
      batch = db.batch();
    }
  }

  await batch.commit();
  print("✅ Đã cập nhật $updatedCount địa điểm cho $collectionName");
}

DateTime? _parseCreatedAt(dynamic createdAt) {
  if (createdAt == null) return null;

  if (createdAt is Timestamp) {
    return createdAt.toDate();
  } else if (createdAt is String && createdAt.isNotEmpty) {
    try {
      return DateTime.parse(createdAt);
    } catch (_) {
      return null;
    }
  }
  return null;
}
