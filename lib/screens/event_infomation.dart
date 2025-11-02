import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EventDetailScreen extends StatelessWidget {
  final String eventId;
  final String groupId;
  const EventDetailScreen({super.key, required this.eventId, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFF4A5C3B);
    final Color joinColor = const Color(0xFFFBE6A1);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('events')
              .doc(eventId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.data!.exists) {
              return const Center(child: Text('Không tìm thấy sự kiện'));
            }

            final event = snapshot.data!;
            final creator = event['createdBy'];
            final members = event['joined'];
            final currentUid = FirebaseAuth.instance.currentUser?.uid;
            final joined = members.map((e) => e['id'] as String).toList();
            final joinedByUser = currentUid != null && joined.contains(currentUid);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔹 Header
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Color(0xFF4A5C3B)),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'THÔNG TIN SỰ KIỆN',
                            style: TextStyle(
                              color: Color(0xFF4A5C3B),
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 🔹 Nội dung sự kiện
                  _buildInfoItem('Tên sự kiện', event['title']),
                  _buildInfoItem('Địa điểm', event['destination']),
                  _buildInfoItem('Thời gian', _formatTimeRange(
                      event['startDate'],
                      event['startTime'],
                      event['endDate'],
                      event['endTime'],
                    ),
                  ),
                  _buildInfoItem('Nơi tập trung', event['place']),
                  _buildInfoItem('Mô tả', event['description']),
                  _buildInfoItem('Lưu ý', event['note']),

                  const SizedBox(height: 16),

                  // 🔹 Người tạo sự kiện
                  const Text(
                    'Người tạo sự kiện',
                    style: TextStyle(
                      color: Color(0xFF4A5C3B),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundImage: NetworkImage(creator['avatarUrl']),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        creator['name'] ?? '',
                        style: const TextStyle(
                          color: Color(0xFF4A5C3B),
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: const Text(
                      'Thành viên tham gia',
                      style: TextStyle(
                        color: Color(0xFF4A5C3B),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      for (var m in members) _buildMemberCircle(m['avatarUrl'], m['name']),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // 🔹 Nút tham gia
                  Center(
                    child: ElevatedButton(
                          onPressed: () => _toggleJoinEvent(eventId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: joinedByUser ? const Color(0xFF9DB596) : Colors.white,
                            side: const BorderSide(color: Color(0xFF2E582B)),
                            foregroundColor: joinedByUser ? Colors.white : const Color(0xFF2E582B),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(joinedByUser ? 'Đã tham gia' : 'Tham gia',)
                      ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatTimeRange(String? startDate, String? startTime, String? endDate, String? endTime) {
    if (startDate == null || startTime == null || endDate == null || endTime == null) return '';

    // Parse ngày để format lại thành dd/MM/yyyy
    try {
      final start = DateTime.parse(startDate);
      final end = DateTime.parse(endDate);
      final startStr = '${startTime.replaceAll(':', 'h ')}${DateFormat('dd/MM/yyyy').format(start)}';
      final endStr = '${endTime.replaceAll(':', 'h ')}${DateFormat('dd/MM/yyyy').format(end)}';
      return '$startStr - $endStr';
    } catch (e) {
      return '$startTime $startDate - $endTime $endDate';
    }
  }

  Widget _buildInfoItem(String title, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF4A5C3B),
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value ?? '',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleJoinEvent(String eventId) async {
    final user = FirebaseAuth.instance.currentUser;

    final docRef = FirebaseFirestore.instance.collection('events').doc(eventId);
    final snap = await docRef.get();
    if (!snap.exists) return;

    final data = snap.data() as Map<String, dynamic>? ?? {};
    final joined = List<Map<String, dynamic>>.from(data['joined'] ?? []);

    final existingIndex = joined.indexWhere((j) => j['id'] == user?.uid);

    if (existingIndex >= 0) {
      joined.removeAt(existingIndex);
    } else {
      joined.add({
        'id': user?.uid,
        'name': user?.displayName ?? '',
        'avatarUrl': user?.photoURL ?? '',
      });
    }

    await docRef.update({'joined': joined});

    final groupRef = FirebaseFirestore.instance.collection('groups').doc(groupId);
    final groupSnap = await groupRef.get();
    if (!groupSnap.exists) return;

    final groupData = groupSnap.data() as Map<String, dynamic>? ?? {};
    final events = List<Map<String, dynamic>>.from(groupData['events'] ?? []);

    bool updated = false;

    final newEvents = events.map((ev) {
      if (ev['id'] == eventId) {
        final joined = List<String>.from(ev['joined'] ?? []);
        if (joined.contains(user?.uid)) {
          joined.remove(user?.uid);
        } else {
          joined.add(user!.uid);
        }
        updated = true;
        return {...ev, 'joined': joined};
      }
      return ev;
    }).toList();

    if (updated) {
      await groupRef.update({'events': newEvents});
    }
  }

  Widget _buildMemberCircle(String? avatar, String? name, {bool isAdd = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isAdd
                  ? const Color(0xFFC2D3B3)
                  : const Color(0xFFA2B293),
            ),
            child: Center(
              child: isAdd
                  ? const Text(
                '+',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF324E2A),
                ),
              )
                  : ClipOval(
                child: (avatar != null)
                    ? Image.network(
                  avatar,
                  width: 55,
                  height: 55,
                  fit: BoxFit.cover,
                )
                    : Text((name ?? '?')
                    .toString()
                    .substring(0, 1)
                    .toUpperCase(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF324E2A),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isAdd ? 'Thêm' : (name ?? 'Ẩn danh'),
            style: const TextStyle(color: Color(0xFF324E2A), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
