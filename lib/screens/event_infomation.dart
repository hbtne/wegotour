import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class EventDetailScreen extends StatelessWidget {
  final String eventId;
  final String groupId;
  const EventDetailScreen(
      {super.key, required this.eventId, required this.groupId});

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

            final docSnap = snapshot.data!;
            final doc = docSnap.data() as Map<String, dynamic>? ?? {};

            final creator = (doc['createdBy'] is Map)
                ? Map<String, dynamic>.from(doc['createdBy'])
                : <String, dynamic>{};
            final membersRaw = doc['joined'] ?? [];
            final members = (membersRaw is List)
                ? List<Map<String, dynamic>>.from(membersRaw.map((e) => e is Map
                    ? Map<String, dynamic>.from(e)
                    : {'name': e.toString(), 'avatarUrl': ''}))
                : <Map<String, dynamic>>[];
            final currentUid = FirebaseAuth.instance.currentUser?.uid;
            final joinedIds = members
                .map((e) => (e['id'] ?? '').toString())
                .where((s) => s.isNotEmpty)
                .toList();
            final joinedByUser =
                currentUid != null && joinedIds.contains(currentUid);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔹 Header
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: Color(0xFF4A5C3B)),
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
                  _buildInfoItem(
                      'Tên sự kiện', (doc['title'] ?? '').toString()),
                  _buildInfoItem(
                      'Địa điểm', (doc['destination'] ?? '').toString()),
                  _buildInfoItem(
                    'Thời gian',
                    _formatTimeRange(doc['startDate'], doc['startTime'],
                        doc['endDate'], doc['endTime']),
                  ),
                  _buildInfoItem(
                      'Nơi tập trung', (doc['place'] ?? '').toString()),
                  _buildInfoItem(
                      'Mô tả', (doc['description'] ?? '').toString()),
                  _buildInfoItem('Lưu ý', (doc['note'] ?? '').toString()),

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
                        backgroundImage: (creator['avatarUrl'] != null &&
                                creator['avatarUrl'].toString().isNotEmpty)
                            ? NetworkImage(creator['avatarUrl'])
                            : const AssetImage('assets/default_avatar.png')
                                as ImageProvider,
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

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        for (var m in members)
                          _buildMemberCircle(m['avatarUrl']?.toString(),
                              m['name']?.toString()),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // 🔹 Nút tham gia
                  Center(
                    child: ElevatedButton(
                      onPressed: () => _toggleJoinEvent(context, eventId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: joinedByUser
                            ? const Color(0xFF9DB596)
                            : Colors.white,
                        side: const BorderSide(color: Color(0xFF2E582B)),
                        foregroundColor: joinedByUser
                            ? Colors.white
                            : const Color(0xFF2E582B),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
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

  // Helpers: detect time/date strings
  bool _isTimeString(String s) {
    final timeRe = RegExp(r'^\s*\d{1,2}:\d{2}(\s*[AaPp][Mm])?\s*$');
    return timeRe.hasMatch(s);
  }

  bool _isDateString(String s) {
    // ISO or dd/MM/yyyy
    try {
      DateTime.parse(s);
      return true;
    } catch (_) {
      try {
        DateFormat('dd/MM/yyyy').parseStrict(s);
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  // Robust date/time formatter that accepts multiple input types and handles swapped fields.
  String _formatTimeRange(
      dynamic startDate, String? startTime, dynamic endDate, String? endTime) {
    if (startDate == null ||
        startTime == null ||
        endDate == null ||
        endTime == null) return '';

    DateTime _parseDate(dynamic d) {
      if (d == null) throw FormatException('null date');
      if (d is DateTime) return d;
      if (d is Timestamp) return d.toDate();
      if (d is int) return DateTime.fromMillisecondsSinceEpoch(d);
      if (d is String) {
        // if string is a time (e.g. "9:00 AM") we can't parse as date here
        if (_isTimeString(d)) throw FormatException('Value is time, not date: $d');
        // try ISO first, then dd/MM/yyyy
        try {
          return DateTime.parse(d);
        } catch (_) {
          try {
            return DateFormat('dd/MM/yyyy').parseStrict(d);
          } catch (_) {
            throw FormatException('Invalid date format: $d');
          }
        }
      }
      throw FormatException('Unsupported date type: ${d.runtimeType}');
    }

    // parse time helper must be declared before combine() since combine() uses it
    DateTime _parseTime(String t) {
      // t can be "09:00", "9:00 AM", "09:00 PM"
      if (_isTimeString(t)) {
        final hasAmPm = RegExp(r'([AaPp][Mm])').hasMatch(t);
        try {
          if (hasAmPm) {
            final dt = DateFormat('h:mm a').parse(t.trim());
            return DateTime(0, 1, 1, dt.hour, dt.minute);
          } else {
            final dt = DateFormat('H:mm').parse(t.trim());
            return DateTime(0, 1, 1, dt.hour, dt.minute);
          }
        } catch (_) {
          // fallback split
          final parts = t
              .trim()
              .split(RegExp(r'[:\s]'))
              .where((s) => s.isNotEmpty)
              .toList();
          final h = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
          final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
          return DateTime(0, 1, 1, h, m);
        }
      }
      // not a time string -> try to parse as date-time then take time
      try {
        final dt = DateTime.parse(t);
        return DateTime(0, 1, 1, dt.hour, dt.minute);
      } catch (_) {
        throw FormatException('Invalid time format: $t');
      }
    }

    DateTime _combine(dynamic datePart, String timePart) {
      // handle swapped inputs: if datePart is a time-string and timePart is a date-string -> swap
      if (datePart is String &&
          _isTimeString(datePart) &&
          timePart.isNotEmpty &&
          _isDateString(timePart)) {
        final parsedDate = _parseDate(timePart);
        final parsedTime = _parseTime(datePart);
        return DateTime(parsedDate.year, parsedDate.month, parsedDate.day,
            parsedTime.hour, parsedTime.minute);
      }

      // normal case: datePart is date-like
      final parsedDate = _parseDate(datePart);
      final parsedTime = _parseTime(timePart);
      return DateTime(parsedDate.year, parsedDate.month, parsedDate.day,
          parsedTime.hour, parsedTime.minute);
    }

    try {
      final s = _combine(startDate, startTime!);
      final e = _combine(endDate, endTime!);
      final startStr =
          '${DateFormat('HH:mm').format(s)} ${DateFormat('dd/MM/yyyy').format(s)}';
      final endStr =
          '${DateFormat('HH:mm').format(e)} ${DateFormat('dd/MM/yyyy').format(e)}';
      return '$startStr - $endStr';
    } catch (e) {
      // fallback to raw string representation
      return '${startTime ?? ''} ${startDate ?? ''} - ${endTime ?? ''} ${endDate ?? ''}';
    }
  }

  Future<void> _toggleJoinEvent(BuildContext context, String eventId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (kDebugMode) print('User not authenticated');
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Bạn cần đăng nhập để tham gia sự kiện')));
      return;
    }

    try {
      final docRef =
          FirebaseFirestore.instance.collection('events').doc(eventId);
      final snap = await docRef.get();
      if (!snap.exists) return;

      final data = snap.data() as Map<String, dynamic>? ?? {};
      final joined = List<Map<String, dynamic>>.from(data['joined'] ?? []);

      final existingIndex = joined.indexWhere((j) => j['id'] == user.uid);

      if (existingIndex >= 0) {
        joined.removeAt(existingIndex);
      } else {
        joined.add({
          'id': user.uid,
          'name': user.displayName ?? '',
          'avatarUrl': user.photoURL ?? '',
        });
      }

      await docRef.update({'joined': joined});

      final groupRef =
          FirebaseFirestore.instance.collection('groups').doc(groupId);
      final groupSnap = await groupRef.get();
      if (!groupSnap.exists) return;

      final groupData = groupSnap.data() as Map<String, dynamic>? ?? {};
      final eventsRaw = groupData['events'] ?? [];
      final events = (eventsRaw is List)
          ? List<Map<String, dynamic>>.from(eventsRaw.map((e) =>
              e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}))
          : <Map<String, dynamic>>[];

      bool updated = false;

      final newEvents = events.map((ev) {
        if ((ev['id'] ?? '').toString() == eventId) {
          final joinedList = List<String>.from(ev['joined'] ?? []);
          if (joinedList.contains(user.uid)) {
            joinedList.remove(user.uid);
          } else {
            joinedList.add(user.uid);
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
      // existingIndex < 0 => user just joined
      if (existingIndex < 0) {
        await _addToGoogleCalendar(context, data);
      }
    } catch (e) {
      if (kDebugMode) print('_toggleJoinEvent error: $e');
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Thao tác thất bại')));
    }
  }

  Future<void> _addToGoogleCalendar(
      BuildContext context, Map<String, dynamic> event) async {
    try {
      final title = (event['title'] ?? '').toString();
      final description = (event['description'] ?? '').toString();
      final note = (event['note'] ?? '').toString();
      final details = description + (note.isNotEmpty ? '\nLưu ý: $note' : '');
      final location =
          (event['place'] ?? event['destination'] ?? '').toString();

      final dynamic sd = event['startDate'];
      final String stRaw = (event['startTime'] ?? '').toString();
      final dynamic ed = event['endDate'];
      final String etRaw = (event['endTime'] ?? '').toString();

      if (sd == null || stRaw.isEmpty || ed == null || etRaw.isEmpty) {
        if (context.mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content:
                  Text('Thiếu thời gian sự kiện để thêm vào Google Calendar')));
        return;
      }

      // local helper parse Date
      DateTime _parseDate(dynamic d) {
        if (d == null) throw FormatException('null date');
        if (d is DateTime) return d;
        if (d is Timestamp) return d.toDate();
        if (d is int) return DateTime.fromMillisecondsSinceEpoch(d);
        if (d is String) {
          // if string is time-like, throw here so caller may swap fields
          if (_isTimeString(d)) throw FormatException('Value is time, not date: $d');
          try {
            return DateTime.parse(d);
          } catch (_) {
            try {
              return DateFormat('dd/MM/yyyy').parseStrict(d);
            } catch (_) {
              throw FormatException('Không thể parse ngày: $d');
            }
          }
        }
        throw FormatException('Unsupported date type: ${d.runtimeType}');
      }

      DateTime _parseTime(String t) {
        if (_isTimeString(t)) {
          final hasAmPm = RegExp(r'([AaPp][Mm])').hasMatch(t);
          try {
            if (hasAmPm) {
              final dt = DateFormat('h:mm a').parse(t.trim());
              return DateTime(0, 1, 1, dt.hour, dt.minute);
            } else {
              final dt = DateFormat('H:mm').parse(t.trim());
              return DateTime(0, 1, 1, dt.hour, dt.minute);
            }
          } catch (_) {
            final parts = t
                .trim()
                .split(RegExp(r'[:\s]'))
                .where((s) => s.isNotEmpty)
                .toList();
            final h = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
            final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
            return DateTime(0, 1, 1, h, m);
          }
        }
        // not a time string -> try parse as DateTime and take time component
        try {
          final dt = DateTime.parse(t);
          return DateTime(0, 1, 1, dt.hour, dt.minute);
        } catch (_) {
          throw FormatException('Invalid time format: $t');
        }
      }

      // combine with swap detection
      DateTime combineWithSwap(dynamic datePart, String timePart) {
        // if datePart is String and actually a time, and timePart looks like date -> swap
        if (datePart is String &&
            _isTimeString(datePart) &&
            timePart.isNotEmpty &&
            _isDateString(timePart)) {
          final parsedDate = _parseDate(timePart);
          final parsedTime = _parseTime(datePart);
          return DateTime(parsedDate.year, parsedDate.month, parsedDate.day,
              parsedTime.hour, parsedTime.minute);
        }
        // otherwise normal
        final parsedDate = _parseDate(datePart);
        final parsedTime = _parseTime(timePart);
        return DateTime(parsedDate.year, parsedDate.month, parsedDate.day,
            parsedTime.hour, parsedTime.minute);
      }

      // Another safety: if developer accidentally swapped (date stored in startTime as date string),
      // try alternative swap: if startTime is date-like and startDate is date-like but startTime is full date (no time)
      dynamic fixedSd = sd;
      String fixedSt = stRaw;
      dynamic fixedEd = ed;
      String fixedEt = etRaw;

      // If startTime looks like a date (e.g. "06/11/2025") and startDate is date-like or timestamp OR startDate is time-like
      if (stRaw.isNotEmpty &&
          !_isTimeString(stRaw) &&
          _isDateString(stRaw) &&
          (sd == null ||
              sd is String && _isTimeString(sd) ||
              sd is String && !_isDateString(sd))) {
        // swap
        fixedSd = stRaw;
        fixedSt = sd?.toString() ?? '';
      }

      // If endTime looks like a date -> swap
      if (etRaw.isNotEmpty &&
          !_isTimeString(etRaw) &&
          _isDateString(etRaw) &&
          (ed == null ||
              ed is String && _isTimeString(ed) ||
              ed is String && !_isDateString(ed))) {
        fixedEd = etRaw;
        fixedEt = ed?.toString() ?? '';
      }

      // final combine (this also handles the more common swap where datePart is a time string)
      final start = combineWithSwap(fixedSd, fixedSt);
      var end = combineWithSwap(fixedEd, fixedEt);

      // If end is before or equal start, set default +1 hour
      if (!end.isAfter(start)) {
        end = start.add(const Duration(hours: 1));
      }

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
        if (kDebugMode) print('Cannot launch $uri');
        if (context.mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Không thể mở Google Calendar')));
      }
    } catch (e, st) {
      if (kDebugMode) {
        print('_addToGoogleCalendar error: $e');
        print(st);
      }
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Thêm lịch thất bại')));
    }
  }

  Widget _buildMemberCircle(String? avatar, String? name,
      {bool isAdd = false}) {
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
                              (name ?? '?').toString().isNotEmpty
                                  ? (name ?? '?')
                                      .toString()
                                      .substring(0, 1)
                                      .toUpperCase()
                                  : '?',
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
