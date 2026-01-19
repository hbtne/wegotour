import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:stour/screens/group.dart';
import 'package:stour/screens/list_group_message.dart';
import 'package:stour/screens/collection_events.dart';
import 'package:stour/widgets/item_post.dart';

import '../services/auth_service.dart';
import 'addPost_screen.dart';
import '../assets/icons/group_feed_bar.dart';
import '../assets/icons/chat_feed_bar.dart';

class Feeds extends StatefulWidget {
  const Feeds({super.key});

  @override
  State<Feeds> createState() => _FeedsState();
}

class _FeedsState extends State<Feeds> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? userData;

  /// Cache user để không fetch lại khi scroll
  final Map<String, Map<String, dynamic>> _userCache = {};

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    setState(() {
      userData = doc.data();
    });
  }

  /// Load user theo batch (1 future duy nhất)
  Future<Map<String, Map<String, dynamic>>> _preloadUsers(
      List<QueryDocumentSnapshot> posts,
      ) async {
    final authorIds = posts
        .map((e) => e['authorId'])
        .whereType<String>()
        .toSet();

    for (final uid in authorIds) {
      if (_userCache.containsKey(uid)) continue;

      final doc = await _firestore.collection('users').doc(uid).get();
      _userCache[uid] = doc.data() ?? {};
    }

    return _userCache;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          _buildAddPost(userData?['avatar']),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('posts')
                  .orderBy('createdAt', descending: true)
                  .limit(30)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData) {
                  return const Center(child: Text('Không có dữ liệu'));
                }

                final docs = snapshot.data!.docs;

                return FutureBuilder<Map<String, Map<String, dynamic>>>(
                  future: _preloadUsers(docs),
                  builder: (context, userSnap) {
                    if (!userSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return _buildFeedList(docs, userSnap.data!);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ================= UI =================

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      centerTitle: true,
      title: const Text(
        'BẢNG TIN',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF3B6332),
        ),
      ),
      leading: IconButton(
        icon: SvgPicture.string(groupFeedSVG, height: 30, width: 30),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GroupsScreen()),
          );
        },
      ),
      actions: [
        IconButton(
          icon: SvgPicture.string(chatFeedSVG, height: 30, width: 30),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const GroupMessageScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAddPost(String? avatarUrl) {
    return Container(
      padding: const EdgeInsets.all(10),
      color: Colors.white,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.transparent,
            backgroundImage: avatarUrl != null
                ? NetworkImage(avatarUrl)
                : const AssetImage('assets/default_avatar.png')
            as ImageProvider,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              readOnly: true,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AddPostScreen()),
                );
              },
              decoration: InputDecoration(
                hintText: "Chia sẻ cảm nghĩ của bạn...",
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide:
                  const BorderSide(color: Color(0xff2e582b)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedList(
      List<QueryDocumentSnapshot> docs,
      Map<String, Map<String, dynamic>> users,
      ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 10),
      itemCount: docs.length + 1,
      itemBuilder: (context, index) {
        /// Header
        if (index == 0) {
          return ListTile(
            leading: const Icon(Icons.local_offer,
                color: Color(0xFF3B6332)),
            title: const Text(
              'Sự kiện sưu tầm',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF3B6332),
              ),
            ),
            subtitle: const Text(
              'Tham gia, đăng bài và nhận huy hiệu',
              style: TextStyle(color: Color(0xFF3B6332)),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CollectionEventsList(),
              ),
            ),
          );
        }

        final postDoc = docs[index - 1];
        final data = postDoc.data() as Map<String, dynamic>;
        final user = users[data['authorId']] ?? {};

        final currentUid = AuthService.getCurrentUserId();
        final isLiked = currentUid != null &&
            List<String>.from(data['likedBy'] ?? [])
                .contains(currentUid);

        return PostItem(
          postId: postDoc.id,
          groupId: data['groupId'] ?? '',
          groupName: data['groupName'] ?? '',
          content: data['content'] ?? '',
          imageUrls: List<String>.from(data['imageUrls'] ?? []),
          author: user['username'] ?? 'Không tên',
          avatar: user['avatar'] ?? '',
          timeAgo: data['createdAt'],
          location: data['location'] ?? '',
          likes: data['likes'] ?? 0,
          comments: data['comments'] ?? 0,
          shares: data['shares'] ?? 0,
          authorId: data['authorId'],
          placeIds: List<String>.from(data['places'] ?? []),
          isLiked: isLiked,
          highlightCommentId: null,
        );
      },
    );
  }
}
