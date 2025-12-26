import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:stour/assets/icons/event_svg.dart';
import 'package:stour/assets/icons/chat_svg.dart';
import 'package:stour/screens/add_event.dart';
import 'package:stour/screens/group_detail.dart';
import 'package:stour/screens/group_message.dart';
import 'package:stour/services/auth_service.dart';
import 'package:stour/widgets/item_post.dart';
import 'addPost_screen.dart';
import 'package:async/async.dart';

class GroupPostScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupPostScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupPostScreen> createState() => _GroupPostScreenState();
}

class _GroupPostScreenState extends State<GroupPostScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfffefefe),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                children: [
                  _buildAppBar(context, widget.groupId, widget.groupName),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xff2e582b),
                            ),
                            child: IconButton(
                              icon: SvgPicture.string(eventSVG, height: 24, width: 24),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => CreateEventScreen(groupId: widget.groupId,)),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xfffff3c4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GroupDetailScreen(
                                  groupId: widget.groupId,
                                  groupName: widget.groupName,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Row(
                              children: const [
                                Icon(
                                  Icons.info_outline,
                                  color: Color(0xff2e582b),
                                  size: 18,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Thông tin nhóm',
                                  style: TextStyle(
                                    color: Color(0xff2e582b),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildAddPost(AuthService.getCurrentUserAvatar()),
                ],
              ),
            ),

            // 🔹 StreamBuilder lắng nghe thay đổi của nhóm
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: _firestore.collection('groups').doc(widget.groupId).snapshots(),
                builder: (context, groupSnapshot) {
                  if (!groupSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final groupData = groupSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                  final postIds = List<String>.from(groupData['posts'] ?? []);

                  if (postIds.isEmpty) {
                    return const Center(child: Text('Chưa có bài đăng nào.'));
                  }

                  // 🔹 Lấy tất cả users trước, dùng FutureBuilder vì ít thay đổi
                  return FutureBuilder<QuerySnapshot>(
                    future: _firestore.collection('users').get(),
                    builder: (context, usersSnapshot) {
                      if (!usersSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final users = {
                        for (var u in usersSnapshot.data!.docs)
                          u.id: u.data() as Map<String, dynamic>
                      };

                      // 🔹 Stream cho posts, chia batch tối đa 10
                      final postStreams = <Stream<QuerySnapshot>>[];
                      for (var i = 0; i < postIds.length; i += 10) {
                        final batch = postIds.skip(i).take(10).toList();
                        postStreams.add(_firestore
                            .collection('posts')
                            .where(FieldPath.documentId, whereIn: batch)
                            .snapshots());
                      }

                      return StreamBuilder<List<QuerySnapshot>>(
                        stream: StreamZip(postStreams),
                        builder: (context, postsSnapshots) {
                          if (!postsSnapshots.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final allPosts = postsSnapshots.data!
                              .expand((snap) => snap.docs)
                              .toList()
                            ..sort((a, b) {
                              final at = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
                              final bt = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
                              return bt.compareTo(at);
                            });

                          return ListView.builder(
                            itemCount: allPosts.length,
                            itemBuilder: (context, index) {
                              final post = allPosts[index];
                              final data = post.data() as Map<String, dynamic>;
                              final user = users[data['authorId']] ?? {};
                              final currentUid = AuthService.getCurrentUserId();
                              final isLiked = currentUid != null &&
                                  List<String>.from(post['likedBy'] ?? []).contains(currentUid);

                              return PostItem(
                                postId: post.id,
                                groupId: widget.groupId,
                                groupName: widget.groupName,
                                content: data['content'] ?? '',
                                imageUrls: List<String>.from(data['imageUrls'] ?? []),
                                timeAgo: data['createdAt'] as Timestamp,
                                location: data['location'] ?? '',
                                likes: data['likes'] ?? 0,
                                comments: data['comments'] ?? 0,
                                shares: data['shares'] ?? 0,
                                authorId: data['authorId'] ?? '',
                                placeIds: List<String>.from(data['places'] ?? []),
                                author: user['username'] ?? 'Ẩn danh',
                                avatar: user['avatar'] ?? '',
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
            )
          ],
        ),
      ),
    );
  }

  // 🔸 AppBar
  AppBar _buildAppBar(BuildContext context, String groupId, String groupName) {
    return AppBar(
      backgroundColor: Colors.white,
      centerTitle: true,
      title: Text(
        groupName,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF3B6332),
        ),
        overflow: TextOverflow.ellipsis,
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF23340A)),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
      actions: [
        IconButton(
          icon: SvgPicture.string(chatSVG, height: 30, width: 30),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GroupChatScreen(
                  groupId: groupId,
                  groupName: groupName
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // 🔸 Ô "Thêm bài viết"
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
                : const AssetImage('assets/default_avatar.png') as ImageProvider,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              readOnly: true, // không bật bàn phím
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AddPostScreen(groupId: widget.groupId, groupName: widget.groupName,)),
                );
              },
              decoration: InputDecoration(
                hintText: "Chia sẻ cảm nghĩ của bạn...",
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
}
