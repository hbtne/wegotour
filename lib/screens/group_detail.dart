import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:stour/assets/icons/championship_cup.dart';
import 'package:stour/assets/icons/chat_svg.dart';
import 'package:stour/assets/icons/event_calendar.dart';
import 'package:stour/screens/friend_message.dart';
import 'package:stour/screens/group_message.dart';
import 'event_infomation.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  const GroupDetailScreen({Key? key, required this.groupId, required this.groupName}) : super(key: key);

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final Map<String, QueryDocumentSnapshot> _eventsMap = {};
  final List<StreamSubscription<QuerySnapshot>> _subscriptions = [];
  List<String> _prevEventIds = [];

  @override
  void dispose() {
    for (final s in _subscriptions) s.cancel();
    _subscriptions.clear();
    _eventsMap.clear();
    super.dispose();
  }

  Future<void> _toggleJoinEvent(String eventId) async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn cần đăng nhập để tham gia sự kiện')),
      );
      return;
    }

    final docRef = _firestore.collection('events').doc(eventId);
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

    final groupRef = _firestore.collection('groups').doc(widget.groupId);
    final groupSnap = await groupRef.get();
    if (!groupSnap.exists) return;

    final groupData = groupSnap.data() as Map<String, dynamic>? ?? {};
    final events = List<Map<String, dynamic>>.from(groupData['events'] ?? []);

    bool updated = false;

    final newEvents = events.map((ev) {
      if (ev['id'] == eventId) {
        final joined = List<String>.from(ev['joined'] ?? []);
        if (joined.contains(user.uid)) {
          joined.remove(user.uid);
        } else {
          joined.add(user.uid);
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

  @override
  Widget build(BuildContext context) {
    final groupRef = _firestore.collection('groups').doc(widget.groupId);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2E582B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.groupName, style: const TextStyle(color: Color(0xFF2E582B), fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: SvgPicture.string(chatSVG, width: 30, height: 30),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => GroupChatScreen(groupId: widget.groupId, groupName: widget.groupName))),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: groupRef.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snap.hasData || !snap.data!.exists) return const Center(child: Text('Không tìm thấy nhóm'));
          final data = snap.data!.data() as Map<String, dynamic>? ?? {};

          final leaderboard = List<Map<String, dynamic>>.from(data['leaderboard'] ?? []);
          final members = List<Map<String, dynamic>>.from(data['members'] ?? []);

          final eventsList = List<Map<String, dynamic>>.from(data['events'] ?? []);

          Widget buildLeaderboard() => Column(
            children: leaderboard
                .map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(flex: 2, child: Text(e['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(child: Text('${e['likes'] ?? 0} lượt thích', textAlign: TextAlign.center)),
                  Expanded(child: Text('${e['comments'] ?? 0} bình luận', textAlign: TextAlign.center)),
                ],
              ),
            ))
                .toList(),
          );

          Widget buildEvents() => Column(
            children: eventsList.map((ev) {
              final currentUid = _auth.currentUser?.uid;
              final joined = List<String>.from(ev['joined'] ?? []);
              final joinedByUser = currentUid != null && joined.contains(currentUid);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: ev['id'], groupId: widget.groupId,)),
                        ),
                        child: Text(
                          ev['title'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E582B),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                    Expanded(child: Text(ev['time'] ?? '')),
                    Expanded(child: Text(ev['place'] ?? '')),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 200,
                      child: ElevatedButton(
                        onPressed: () => _toggleJoinEvent(ev['id']),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: joinedByUser ? const Color(0xFF9DB596) : Colors.white,
                          side: const BorderSide(color: Color(0xFF2E582B)),
                          foregroundColor: joinedByUser ? Colors.white : const Color(0xFF2E582B),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(joinedByUser ? 'Đã tham gia' : 'Tham gia',)
                      ),
                    )
                  ],
                ),
              );
            }).toList(),
          );

          Widget buildMembers() => Column(
            children: members.map((m) {
              final isCurrent = m['id'] == _auth.currentUser?.uid;
              final name = m['name'] ?? '';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold))),
                    Row(
                      children: [
                        IconButton(
                            onPressed: () => Navigator.push(
                                context, MaterialPageRoute(builder: (_) => PersonalChatScreen(friendId: m['id'], friendName: name))),
                            icon: SvgPicture.string(chatSVG, width: 20, height: 20)),
                        const SizedBox(width: 8),
                        IconButton(
                            onPressed: () {}, icon: Icon(isCurrent ? Icons.person : Icons.person_add, color: const Color(0xFF9DB596))),
                      ],
                    )
                  ],
                ),
              );
            }).toList(),
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                const Text('Tên nhóm', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E582B))),
                const SizedBox(height: 6),
                Text(data['name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                const Text('Mô tả', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E582B))),
                const SizedBox(height: 6),
                Text(data['description'] ?? '', style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 20),
                Row(children: [
                  const Text('Bảng vinh danh', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E582B))),
                  const SizedBox(width: 8),
                  SvgPicture.string(championshipCupSVG, width: 20, height: 20),
                ]),
                const SizedBox(height: 10),
                buildLeaderboard(),
                const SizedBox(height: 20),
                Row(children: [
                  const Text('Sự kiện', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E582B))),
                  const SizedBox(width: 8),
                  SvgPicture.string(eventCalendarSVG, width: 20, height: 20),
                ]),
                const SizedBox(height: 12),
                Row(
                  children: const [
                    Expanded(flex: 2, child: Text('Tên sự kiện', style: TextStyle(color: Color(0xFF2E582B), fontWeight: FontWeight.bold))),
                    Expanded(child: Text('Thời gian', style: TextStyle(color: Color(0xFF2E582B), fontWeight: FontWeight.bold))),
                    Expanded(child: Text('Tập hợp ở', style: TextStyle(color: Color(0xFF2E582B), fontWeight: FontWeight.bold))),
                    SizedBox(width: 80),
                  ],
                ),
                const SizedBox(height: 10),
                buildEvents(),
                const SizedBox(height: 20),
                const Text('Số thành viên', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E582B))),
                const SizedBox(height: 6),
                Text('${members.length} người', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                buildMembers(),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () => _showInviteDialog(context),
                    icon: const Icon(Icons.add, color: Color(0xFF2E582B)),
                    label: const Text('Mời bạn', style: TextStyle(color: Color(0xFF2E582B))),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF9E3A2),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showInviteDialog(BuildContext context) async {
    final usersSnap = await _firestore.collection('users').get();
    final allUsers = usersSnap.docs.map((d) => {'id': d.id, 'username': d['username']}).toList();
    final selected = <Map<String, dynamic>>[];

    showDialog(
        context: context,
        builder: (_) => StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('Chọn bạn bè'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: ListView.builder(
                itemCount: allUsers.length,
                itemBuilder: (ctx, i) {
                  final u = allUsers[i];
                  final isSel = selected.contains(u);
                  return CheckboxListTile(
                    title: Text(u['username']),
                    value: isSel,
                    onChanged: (v) => setState(() => v == true ? selected.add(u) : selected.remove(u)),
                  );
                },
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
              ElevatedButton(
                  onPressed: () async {
                    if (selected.isNotEmpty) {
                      final groupRef = _firestore.collection('groups').doc(widget.groupId);
                      for (var u in selected) {
                        await groupRef.update({
                          'members': FieldValue.arrayUnion([{'id': u['id'], 'name': u['username']}])
                        });
                      }
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('Xác nhận'))
            ],
          );
        }));
  }
}
