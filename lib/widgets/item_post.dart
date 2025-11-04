import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../screens/addPost_screen.dart';
import '../screens/comment_screen.dart';
import '../screens/group_post.dart';
import '../util/const.dart';

class PostItem extends StatelessWidget {
  final String postId;
  final String groupId;
  final String groupName;
  final String content;
  final List<String> imageUrls;
  final Timestamp timeAgo;
  final String location;
  final int likes;
  final int comments;
  final int shares;
  final String authorId;
  final List<String> placeIds;
  final String author;
  final String avatar;

  PostItem({
    super.key,
    required this.postId,
    required this.groupId,
    required this.groupName,
    required this.content,
    required this.imageUrls,
    required this.timeAgo,
    required this.location,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.authorId,
    required this.placeIds,
    required this.author,
    required this.avatar

  });

  static final _firestore = FirebaseFirestore.instance;
  
  Future<List<Map<String, dynamic>>> _fetchPlacesFromIds(
      List<String> placeIds) async {
    final List<Map<String, dynamic>> places = [];
    for (String id in placeIds) {
      final doc =
      await _firestore.collection("places").doc(id).get(); // ví dụ: places
      if (doc.exists) {
        places.add(doc.data()!..['id'] = doc.id);
      }
    }
    return places;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchPlacesFromIds(placeIds),
      builder: (context, snapshot) {
        final placeTags = snapshot.data ?? [];

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          child: Card(
            margin: const EdgeInsets.all(0.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context),
                _buildContent(),
                if (location.isNotEmpty) _buildLocation(),
                if (imageUrls.isNotEmpty) _buildImages(),
                if (placeTags.isNotEmpty) _buildPlaceTags(placeTags),
                _buildFooter(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: avatar.isNotEmpty
                    ? NetworkImage(avatar)
                    : const AssetImage('assets/default_avatar.png')
                as ImageProvider,
              ),
              const SizedBox(width: 10),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        author,
                        style: const TextStyle(
                          color: Color(0xFF2E5E2A),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (groupId != null && groupId.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GroupPostScreen(
                                  groupId: groupId,
                                  groupName: groupName,
                                ),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              const Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: Color(0xFF2E5E2A),
                              ),
                              Text(
                                groupName,
                                style: const TextStyle(
                                  color: Color(0xFF2E5E2A),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getTimeAgo(timeAgo),
                    style: const TextStyle(
                      color: Color.fromARGB(173, 35, 52, 10),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 🔹 Dấu 3 chấm
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenu(context, value),
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: "delete",
                child: Text("Xóa bài viết"),
              ),
              const PopupMenuItem(
                value: "edit",
                child: Text("Chỉnh sửa bài viết"),
              ),
            ],
            child: const Icon(
              Icons.more_vert,
              color: Color(0xFFFFD54F), // vàng nhạt
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        content,
        style: const TextStyle(
          fontSize: 18,
          color: Color.fromARGB(255, 35, 52, 10),
        ),
      ),
    );
  }

  Widget _buildLocation() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      child: Row(
        children: [
          const Icon(Icons.location_on, size: 16, color: Colors.grey),
          const SizedBox(width: 5),
          Text(
            location,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildImages() {
    return SizedBox(
      height: 250,
      child: PageView.builder(
        itemCount: imageUrls.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrls[index],
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(child: Icon(Icons.error));
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaceTags(List<Map<String, dynamic>> placeTags) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Wrap(
        spacing: 6,
        children: placeTags.map((place) {
          return Chip(
            avatar: const Icon(
              Icons.location_on,
              size: 18,
              color: Color(0xFFFFD166),
            ),
            label: Text(
              place['name'] ?? 'Địa điểm',
              style: const TextStyle(color: Colors.black87),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () => _handleLike(context),
            child: Row(
              children: [
                const Icon(Icons.favorite_outline,
                    color: Color.fromARGB(255, 255, 12, 109)),
                const SizedBox(width: 5),
                Text(likes.toString()),
              ],
            ),
          ),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CommentScreen(postId: postId),
                ),
              );
            },
            child: Row(
              children: [
                Icon(Icons.comment_outlined, color: Constants.darkgreen),
                const SizedBox(width: 5),
                Text(comments.toString()),
              ],
            ),
          ),
          InkWell(
            onTap: () => _handleShare(context),
            child: Row(
              children: [
                Icon(Icons.share_outlined, color: Constants.darkpp),
                const SizedBox(width: 5),
                Text(shares.toString()),
              ],
            ),
          )
        ],
      ),
    );
  }

  /// ---------------- LOGIC ----------------

  Future<void> _handleMenu(BuildContext context, String value) async {
    if (value == "delete") {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Xác nhận xóa"),
          content: const Text("Bạn có chắc chắn muốn xóa bài viết này?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Hủy"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Xóa"),
            ),
          ],
        ),
      );

      if (confirm == true) {
        try {
          await _firestore.collection('posts').doc(postId).delete();

          if (authorId.isNotEmpty) {
            final userRef = _firestore.collection('users').doc(authorId);
            await userRef.update({
              'posts': FieldValue.arrayRemove([postId]),
            });
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Bài viết đã được xóa")),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Xóa bài viết thất bại: $e")),
          );
        }
      }
    } else if (value == "edit") {
      final currentPostData = {
        'content': content,
        'location': location,
        'imageUrls': imageUrls,
      };

      final updated = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => AddPostScreen(
            existingPost: currentPostData,
            postId: postId,
          ),
        ),
      );

      if (updated == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật bài viết thành công')),
        );
      }
    }
  }

  Future<void> _handleLike(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final postRef = _firestore.collection('posts').doc(postId);
    final postDoc = await postRef.get();

    List<dynamic> likedBy = postDoc['likedBy'] ?? [];
    if (!likedBy.contains(currentUser.uid)) {
      await postRef.update({
        'likes': FieldValue.increment(1),
        'likedBy': FieldValue.arrayUnion([currentUser.uid]),
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bạn đã thả like bài viết này")),
      );
    }
  }

  Future<void> _handleShare(BuildContext context) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      await Share.share('Xem bài viết này: $content');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đã xảy ra lỗi khi chia sẻ bài viết.")),
      );
    }
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
