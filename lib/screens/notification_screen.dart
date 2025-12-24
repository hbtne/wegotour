import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:stour/assets/icons/anniversary_notification_svg.dart';
import 'package:stour/assets/icons/communications_notification_svg.dart';
import 'package:stour/assets/icons/event_notification_svg.dart';
import 'package:stour/assets/icons/event_svg.dart';
import 'package:stour/assets/icons/group_bottom_bar.dart';
import 'package:stour/assets/icons/group_feed_bar.dart';
import 'package:stour/assets/icons/mark_all_as_read_svg.dart';
import 'package:stour/screens/post_detail_screen.dart';
import 'package:stour/services/auth_service.dart';

import 'event_infomation.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  Future markAllRead(String userId) async {
    final unread = await FirebaseFirestore.instance
        .collection("users")
        .doc(userId)
        .collection("notifications")
        .where("read", isEqualTo: false)
        .get();

    WriteBatch batch = FirebaseFirestore.instance.batch();

    for (var doc in unread.docs) {
      batch.update(doc.reference, {"read": true});
    }

    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    String userId = AuthService.getCurrentUserId()!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'THÔNG BÁO',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF3B6332),
          ),
        ),
        actions: [
          IconButton(
            icon: SvgPicture.string(markAllAsReadSVG, height: 30, width: 30),
            onPressed: () async {
              markAllRead(userId);
            }),
        ],
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection("users")
            .doc(userId)
            .collection("notifications")
            .orderBy("createdAt", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          final List<DocumentSnapshot> today = [];
          final List<DocumentSnapshot> older = [];

          DateTime now = DateTime.now();

          for (var doc in docs) {
            final ts = doc['createdAt'] as Timestamp;
            DateTime date = ts.toDate();

            bool isToday =
                date.year == now.year &&
                    date.month == now.month &&
                    date.day == now.day;

            if (isToday) {
              today.add(doc);
            } else {
              older.add(doc);
            }
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (today.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text(
                    "Hôm nay",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              ...today.map((doc) => NotificationItem(doc: doc)),

              if (today.isNotEmpty && older.isNotEmpty)
                const SizedBox(height: 20),

              if (older.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text(
                    "Trước đó",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),

              ...older.map((doc) => NotificationItem(doc: doc)),
            ],
          );
        },
      ),
    );
  }
}

class NotificationItem extends StatelessWidget {
  final DocumentSnapshot doc;
  const NotificationItem({super.key, required this.doc});

  void _handleTap(BuildContext context) async {
    final data = doc.data() as Map<String, dynamic>;
    final type = data['type'];
    final payload = data['data'] ?? {};

    await doc.reference.update({'read': true});

    if (type == 'communications' || type == 'anniversary') {
      final postId = payload['postId'];
      final commentId = payload['commentId'];
      if (postId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PostDetailScreen(postId: postId, highlightCommentId: commentId,),
          ),
        );
      }
    }

    if (type == 'event') {
      final eventId = payload['eventId'];
      final groupId = payload['groupId'];
      if (eventId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EventDetailScreen(eventId: eventId, groupId: groupId,),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final ts = data['createdAt'] as Timestamp;

    final iconMap = {
      'communications': communicationNotificationSVG,
      'event': eventNotificationSVG,
      'anniversary': anniversaryNotificationSVG,
    };

    final Color primary = const Color(0xFF4A5C3B);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _handleTap(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: data['read']
              ? Colors.white
              : Colors.amberAccent.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: data['read'] ? Colors.grey.shade300 : primary,
              child: SvgPicture.string(
                iconMap[data['type']] ?? anniversaryNotificationSVG,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['body'],
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getTimeAgo(ts),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(Timestamp timestamp) {
    final now = DateTime.now();
    final postTime = timestamp.toDate();
    final difference = now.difference(postTime);

    if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} tháng trước';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ngày trước';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} giờ trước';
    } else {
      return 'Vừa xong';
    }
  }
}

