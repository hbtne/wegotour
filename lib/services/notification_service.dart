import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../screens/event_infomation.dart';
import '../screens/post_detail_screen.dart';

class NotificationService {
  static final _firestore = FirebaseFirestore.instance;
  static final _messaging = FirebaseMessaging.instance;
  static final _local = FlutterLocalNotificationsPlugin();

  static Future init(String userId) async {
    await _messaging.requestPermission();

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
