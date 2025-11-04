import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

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
          stream: FirebaseFirestore.instance.collection('events').doc(eventId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.data!.exists) {
              return const Center(child: Text('Không tìm thấy sự kiện'));
            }

            final doc = snapshot.data!;
            final creator = doc['createdBy'];
            final members = doc['joined'] ?? [];
            final currentUid = FirebaseAuth.instance.currentUser?.uid;
            final joined = (members as List).map((e) => e['id'] as String).toList();
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
                  _buildInfoItem('Tên sự kiện', doc['title']),
                  _buildInfoItem('Địa điểm', doc['destination']),
                  _buildInfoItem(
                    'Thời gian',
                    _formatTimeRange(doc['startDate'], doc['startTime'], doc['endDate'], doc['endTime']),
                  ),
                  _buildInfoItem('Nơi tập trung', doc['place']),
                  _buildInfoItem('Mô tả', doc['description']),
                  _buildInfoItem('Lưu ý', doc['note']),

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
                        backgroundImage: NetworkImage(creator['avatarUrl'] ?? ''),
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
                      onPressed: () => _toggleJoinEvent(context, eventId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: joinedByUser ? const Color(0xFF9DB596) : Colors.white,
                        side: const BorderSide(color: Color(0xFF2E582B)),
                        foregroundColor: joinedByUser ? Colors.white : const Color(0xFF2E582B),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(joinedByUser ? 'Đã tham gia' : 'Tham gia'),
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

    try {
      final start = DateTime.parse(startDate);
      final end = DateTime.parse(endDate);
      final startStr = '${startTime.replaceAll(':', 'h ')} ${DateFormat('dd/MM/yyyy').format(start)}';
      final endStr = '${endTime.replaceAll(':', 'h ')} ${DateFormat('dd/MM/yyyy').format(end)}';
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

  Future<void> _toggleJoinEvent(BuildContext context, String eventId) async {
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
        final joinedList = List<String>.from(ev['joined'] ?? []);
        if (joinedList.contains(user?.uid)) {
          joinedList.remove(user?.uid);
        } else {
          joinedList.add(user!.uid);
        }
        updated = true;
        return {...ev, 'joined': joinedList};
      }
      return ev;
    }).toList();

    if (updated) {
      await groupRef.update({'events': newEvents});
    }

    // If just joined, open Google Calendar link with event data
    if (existingIndex < 0) {
      await _addToGoogleCalendar(context, data);
    }
  }

  Future<void> _addToGoogleCalendar(BuildContext context, Map<String, dynamic> event) async {
    try {
      final title = (event['title'] ?? '').toString();
      final description = (event['description'] ?? '').toString();
      final note = (event['note'] ?? '').toString();
      final details = description + (note.isNotEmpty ? '\nLưu ý: $note' : '');
      final location = (event['place'] ?? event['destination'] ?? '').toString();

      final String? sd = event['startDate'] as String?;
      final String? st = event['startTime'] as String?;
      final String? ed = event['endDate'] as String?;
      final String? et = event['endTime'] as String?;

      if (sd == null || st == null || ed == null || et == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thiếu thời gian sự kiện để thêm vào Google Calendar')));
        return;
      }

      DateTime parseDateTime(String date, String time) {
        final d = DateTime.parse(date);
        final parts = time.split(':');
        final h = int.tryParse(parts[0]) ?? 0;
        final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
        return DateTime(d.year, d.month, d.day, h, m);
      }

      final start = parseDateTime(sd, st);
      final end = parseDateTime(ed, et);

      // Google Calendar expects UTC formatted like 20250101T090000Z
      final fmt = DateFormat("yyyyMMdd'T'HHmmss'Z'");

      final startStr = fmt.format(start.toUtc());
      final endStr = fmt.format(end.toUtc());

      final uri = Uri.parse(
        'https://www.google.com/calendar/render?action=TEMPLATE'
        '&text=${Uri.encodeComponent(title)}'
        '&details=${Uri.encodeComponent(details)}'
        '&location=${Uri.encodeComponent(location)}'
        '&dates=$startStr/$endStr',
      );

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không thể mở Google Calendar')));
      }
    } catch (e) {
      if (kDebugMode) print('_addToGoogleCalendar error: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thêm lịch thất bại')));
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
              color: isAdd ? const Color(0xFFC2D3B3) : const Color(0xFFA2B293),
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
                      child: (avatar != null && avatar.isNotEmpty)
                          ? Image.network(
                              avatar,
                              width: 55,
                              height: 55,
                              fit: BoxFit.cover,
                            )
                          : Text(
                              (name ?? '?').toString().substring(0, 1).toUpperCase(),
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