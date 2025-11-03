import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:stour/screens/group.dart';
import 'package:stour/screens/list_group_message.dart';
import 'package:stour/widgets/item_post.dart';

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

  @override
  void initState() {
    super.initState();
    _getUser();
  }

  Future<void> _getUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      setState(() {
        userData = doc.data();
      });
    }
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
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Lỗi: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Chưa có bài viết nào'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final postData = snapshot.data!.docs[index];
                    final data = postData.data() as Map<String, dynamic>;
                    final authorId = data['authorId'] ?? '';
                    return FutureBuilder<DocumentSnapshot>(
                      future:
                          _firestore.collection('users').doc(authorId).get(),
                      builder: (context, userSnapshot) {
                        if (userSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const SizedBox();
                        }
                        final user = (userSnapshot.data?.data()
                                as Map<String, dynamic>?) ??
                            {};
                        return PostItem(
                          postId: postData.id,
                          groupId: data['groupId'] ?? '',
                          groupName: data['groupName'] ?? '',
                          content: data['content'] ?? '',
                          imageUrls: List<String>.from(data['imageUrls'] ?? []),
                          timeAgo: data['createdAt'] as Timestamp,
                          location: data['location'] ?? '',
                          likes: data['likes'] ?? 0,
                          comments: data['comments'] ?? 0,
                          shares: data['shares'] ?? 0,
                          authorId: authorId,
                          placeIds: List<String>.from(data['places'] ?? []),
                          author: user['username'] ?? 'Ẩn danh',
                          avatar: user['avatar'] ?? '',
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
        'FEEDS',
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
            MaterialPageRoute(builder: (context) => const GroupsScreen()),
          );
        },
      ),
      actions: [
        IconButton(
            icon: SvgPicture.string(chatFeedSVG, height: 30, width: 30),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GroupMessageScreen(),
                ),
              );
            }),
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
              readOnly: true, // để không bật bàn phím
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => AddPostScreen()
                  ),
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
                  borderSide: const BorderSide(color: Color(0xff2e582b)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchPlacesFromIds(
      List<String> placeIds) async {
    List<Map<String, dynamic>> results = [];

    for (String id in placeIds) {
      for (String col in ['stourplace1', 'food']) {
        final doc = await _firestore.collection(col).doc(id).get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            results.add(data);
            break; // đã tìm thấy thì khỏi tìm tiếp
          }
        }
      }
    }

    return results;
  }
}
