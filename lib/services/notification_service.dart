import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _firestore = FirebaseFirestore.instance;
  static final _messaging = FirebaseMessaging.instance;
  static final _local = FlutterLocalNotificationsPlugin();

  // Khởi tạo
  static Future init(String userId) async {
    // Xin quyền thông báo
    await _messaging.requestPermission();

    // Lấy token FCM
    String? token = await _messaging.getToken();

    if (token != null) {
      await _firestore.collection("users").doc(userId).update({
        "fcmToken": token,
      });
    }

    // Local notification
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _local.initialize(initSettings);

    // Khi app đang mở
    FirebaseMessaging.onMessage.listen((message) {
      _local.show(
        0,
        message.notification?.title,
        message.notification?.body,
        const NotificationDetails(
          android: AndroidNotificationDetails('channel', 'App Notifications'),
        ),
      );
    });
  }
}
