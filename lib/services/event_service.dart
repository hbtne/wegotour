import 'dart:typed_data';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EventService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  /// Upload ảnh:
  /// - Trên mobile/desktop: truyền localPath (đường dẫn tới file hệ thống).
  /// - Trên web: truyền bytes (Uint8List) vì dart:io.File không có.
  /// contentType tùy chọn (ví dụ 'image/jpeg').
  Future<String> uploadSubmissionImage(
    String eventId, {
    String? localPath,
    Uint8List? bytes,
    String? contentType,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final filename = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref().child('submissions/$eventId/$uid/$filename');

    if (kIsWeb) {
      // Web: cần bytes
      if (bytes == null) {
        throw ArgumentError('On web, provide image bytes (Uint8List).');
      }
      final metadata = SettableMetadata(contentType: contentType ?? 'image/jpeg');
      await ref.putData(bytes, metadata);
    } else {
      // Native: cần localPath
      if (localPath == null) {
        throw ArgumentError('On native platforms, provide localPath to the file.');
      }
      await ref.putFile(File(localPath));
    }

    return await ref.getDownloadURL();
  }

  Future<void> createSubmission(String eventId, String imageUrl, String caption) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = _db.collection('eventSubmissions').doc();
    await doc.set({
      'eventId': eventId,
      'userId': uid,
      'imageUrl': imageUrl,
      'caption': caption,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp()
    });
  }
}