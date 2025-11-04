import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';

// 🔹 Firebase config, dùng firebase_options.dart nếu Flutter project
import 'firebase_options.dart';

Future<void> main() async {
  // Khởi tạo Firebase
  WidgetsFlutterBinding.ensureInitialized(); // 🔹 Thêm dòng này
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print("✅ Firebase initialized");

  // Chạy migration
  await migrateStourPlace();
}

Future<void> migrateStourPlace() async {
  await migration("stourplace1");
  await migration("food");

  print("\n🎉 Hoàn tất migration!");
}

Future<void> migration(String collectionName) async {
  final db = FirebaseFirestore.instance;

  final snapshot = await db.collection(collectionName).get();

  if (snapshot.docs.isEmpty) {
    print("⚠️ Không có document nào trong collection: $collectionName");
    return;
  }

  print("🔹 Tìm thấy ${snapshot.docs.length} document, bắt đầu cập nhật...");

  final batch = db.batch();
  final random = Random();

  for (var doc in snapshot.docs) {
    final randomCheckin = random.nextInt(41) + 10; // 10–50
    final randomReview = random.nextInt(41) + 10; // 10–50
    final rating = double.parse((4 + random.nextDouble()).toStringAsFixed(1)); // 10–50
    final ratingYear = double.parse((3 + random.nextDouble() * 2).toStringAsFixed(1)); // 10–50

    final random1 = random.nextInt(11) + 10;
    final random2 = random.nextInt(11) + 10;
    final random3 = random.nextInt(21) + 10;
    final random4 = random.nextInt(21) + 10;

    batch.update(doc.reference, {
      'checkinCount': randomCheckin,
      'reviewCount': randomReview+ random1,
      'checkinCountMonth': randomCheckin + random2,
      'reviewCountMonth': randomReview,
      'ratingMonth': rating.toString(),
      'checkinCountYear': randomCheckin + random3,
      'reviewCountYear': randomReview + random4,
      'ratingYear': ratingYear.toString()
    });

    print("✅ ${doc.id}: checkin=$randomCheckin, review=$randomReview");
  }

  await batch.commit();
}
