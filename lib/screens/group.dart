import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:stour/assets/icons/add_group.dart';
import 'package:stour/assets/icons/all_group.dart';
import 'package:stour/assets/icons/search_group.dart';
import 'package:stour/screens/add_group.dart';
import 'package:stour/screens/find_group.dart';
import 'package:stour/screens/list_group.dart';
import 'package:stour/screens/list_group_message.dart';

import '../services/auth_service.dart';
import '../widgets/item_post.dart';
import '../assets/icons/chat_feed_bar.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
  }

  Future<List<String>> _getUserGroupIds() async {
    final uid = AuthService.getCurrentUserId();
    final userSnap = await _firestore.collection('users').doc(uid).get();

    final data = userSnap.data();
    if (data == null || data['groupIds'] == null) return [];

    return List<String>.from(data['groupIds']);
  }

  Stream<QuerySnapshot> _postsByGroupsStream(List<String> groupIds) {
    return _firestore
        .collection('posts')
        .where('groupId', whereIn: groupIds)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          _buildTopActions(),
          Expanded(
            child: FutureBuilder<List<String>>(
              future: _getUserGroupIds(),
              builder: (context, groupSnapshot) {
                if (groupSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final groupIds = groupSnapshot.data ?? [];

                if (groupIds.isEmpty) {
                  return const Center(child: Text('Bạn chưa tham gia nhóm nào'));
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: _postsByGroupsStream(groupIds),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('Chưa có bài viết nào'));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final postDoc = snapshot.data!.docs[index];
                        final data = postDoc.data() as Map<String, dynamic>;
                        final authorId = data['authorId'] ?? '';

                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(authorId)
                              .get(),
                          builder: (context, userSnapshot) {
                            if (!userSnapshot.hasData) return const SizedBox();

                            final userData =
                                userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                            final currentUid = AuthService.getCurrentUserId();
                            final isLiked = currentUid != null &&
                                List<String>.from(data['likedBy'] ?? []).contains(currentUid);

                            return PostItem(
                              postId: postDoc.id,
                              groupId: data['groupId'] ?? '',
                              groupName: data['groupName'] ?? '',
                              content: data['content'] ?? '',
                              imageUrls:
                              List<String>.from(data['imageUrls'] ?? []),
                              author: userData['username'] ?? 'Ẩn danh',
                              timeAgo: data['createdAt'] as Timestamp,
                              location: data['location'] ?? '',
                              avatar: userData['avatar'] ?? '',
                              likes: data['likes'] ?? 0,
                              comments: data['comments'] ?? 0,
                              shares: data['shares'] ?? 0,
                              authorId: authorId,
                              placeIds: List<String>.from(data['places'] ?? []),
                              isLiked: isLiked,
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      centerTitle: true,
      title: const Text(
        'NHÓM CỦA BẠN',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF3B6332),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back,
            color: Color.fromARGB(255, 35, 52, 10)),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
      actions: [
        IconButton(
          icon: SvgPicture.string(chatFeedSVG, height: 30, width: 30),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const GroupMessageScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTopActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionItem(
            icon: addGroupSVG,
            label: "Tạo mới",
            screen: const CreateGroupScreen(),
          ),
          _buildActionItem(
            icon: allGroupSVG,
            label: "Tất cả nhóm",
            screen: const GroupListScreen(),
          ),
          _buildActionItem(
            icon: searchGroupSVG,
            label: "Tìm nhóm",
            screen: const SearchGroupScreen(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required String icon,
    required String label,
    required Widget screen,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => screen),
        );
      },
      child: Column(
        children: [
          IconButton(
            icon: SvgPicture.string(icon, height: 30, width: 30),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => screen),
              );
            },
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF3B6332),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
