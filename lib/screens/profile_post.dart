import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:stour/services/auth_service.dart';
import 'package:stour/util/const.dart';

import 'addPost_screen.dart';
import 'comment_screen.dart';

class PostScreen extends StatefulWidget {
  final String profileId;
  const PostScreen({super.key, required this.profileId});

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Map<String, Map<String, dynamic>> _userCache = {};

  Future<Map<String, dynamic>> _getUserCached(String uid) async {
    if (_userCache.containsKey(uid)) {
      return _userCache[uid]!;
    }

    final doc = await _firestore.collection('users').doc(uid).get();

    final data = doc.data() ?? {};

    try {
      final selectedBadgeId = data['selectedBadge'];
      if (selectedBadgeId != null && selectedBadgeId.toString().isNotEmpty) {
        final badgesSnapshot = await _firestore
            .collection('users')
            .doc(uid)
            .collection('badges')
            .get();

        // find a badge doc whose id ends with the selectedBadgeId
        QueryDocumentSnapshot? matchingDoc;
        for (var d in badgesSnapshot.docs) {
          if (d.id.endsWith(selectedBadgeId.toString())) {
            matchingDoc = d;
            break;
          }
        }

        if (matchingDoc != null) {
          final badgeData = matchingDoc.data() as Map<String, dynamic>?;
          if (badgeData != null) {
            data['selectedBadgeIcon'] = badgeData['icon'] ?? '';
            data['selectedBadgeName'] = badgeData['name'] ?? '';
          }
        }
      }
    } catch (e) {
      // ignore badge fetch errors
    }

    _userCache[uid] = data;
    return data;
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('posts')
          .where('authorId', isEqualTo: widget.profileId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Center(child: Text('Lỗi: ${snapshot.error}')),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SliverToBoxAdapter(
            child: Center(child: Text('Chưa có bài viết nào')),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final postDoc = snapshot.data!.docs[index];
                final data = postDoc.data() as Map<String, dynamic>;
                final authorId = data['authorId'] ?? '';
                final postId = postDoc.id;

                final placeIds = List<String>.from(data['places'] ?? []);

                return FutureBuilder<Map<String, dynamic>>(
                  future: _getUserCached(authorId),
                  builder: (context, userSnap) {
                    if (!userSnap.hasData) {
                      return const SizedBox();
                    }

                    final user = userSnap.data!;

                    return _buildPostItem(
                      postId: postDoc.id,
                      content: data['content'] ?? '',
                      imageUrls: List<String>.from(data['imageUrls'] ?? []),
                      author: user['username'] ?? 'Không tên',
                      timeAgo: _getTimeAgo(data['createdAt'] as Timestamp),
                      location: data['location'] ?? '',
                      avatarUrl: user['avatar'] ?? '',
                      likes: data['likes'] ?? 0,
                      comments: data['comments'] ?? 0,
                      shares: data['shares'] ?? 0,
                      authorId: data['authorId'],
                      placeIds: placeIds,
                      selectedBadgeIcon: user['selectedBadgeIcon'] ?? '',
                      selectedBadgeName: user['selectedBadgeName'] ?? '',
                    );
                  },
                );
              },
              childCount: snapshot.data!.docs.length,
            ),
          ),
        );
      },
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

  Widget _buildPostItem(
      {required String postId,
      required String content,
      required String avatarUrl,
      required List<String> imageUrls,
      required String author,
      required String timeAgo,
      required String location,
      required int likes,
      required int comments,
      required int shares,
      required String authorId,
      required List<String> placeIds,
      required String? selectedBadgeIcon,
      required String? selectedBadgeName}) {
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
                  // Header với thông tin người đăng
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.transparent,
                              backgroundImage: avatarUrl.isNotEmpty
                                  ? NetworkImage(avatarUrl)
                                  : const AssetImage(
                                          'assets/default_avatar.png')
                                      as ImageProvider,
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  author,
                                  style: const TextStyle(
                                    color: Color.fromARGB(255, 35, 52, 10),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),

                                // badge row (icon + name) similar to item_post
                                if (selectedBadgeIcon != null &&
                                    selectedBadgeIcon.isNotEmpty)
                                  Row(
                                    children: [
                                      ClipOval(
                                        child: Image.network(
                                          selectedBadgeIcon,
                                          width: 18,
                                          height: 18,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                            Icons.emoji_events,
                                            size: 14,
                                            color: Colors.amber,
                                          ),
                                        ),
                                      ),
                                      if (selectedBadgeName != null &&
                                          selectedBadgeName.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(left: 6),
                                          child: Text(
                                            selectedBadgeName,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF2E5E2A),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),

                                const SizedBox(height: 4),
                                Text(
                                  timeAgo,
                                  style: const TextStyle(
                                    color: Color.fromARGB(173, 35, 52, 10),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == "delete") {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text("Xác nhận xóa"),
                                  content: const Text(
                                      "Bạn có chắc chắn muốn xóa bài viết này?"),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text("Hủy"),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text("Xóa"),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                try {
                                  // 1. Xóa bài viết trong posts
                                  await FirebaseFirestore.instance
                                      .collection('posts')
                                      .doc(postId)
                                      .delete();

                                  // 2. Cập nhật document user để xóa postId trong mảng posts
                                  if (authorId.isNotEmpty) {
                                    final userRef = FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(authorId);
                                    await userRef.update({
                                      'posts': FieldValue.arrayRemove([postId]),
                                    });
                                  }

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text("Bài viết đã được xóa")),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text("Xóa bài viết thất bại: $e")),
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
                                  const SnackBar(
                                      content:
                                          Text('Cập nhật bài viết thành công')),
                                );
                              }
                            }
                          },
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
                          child:
                              const Icon(Icons.more_vert, color: Colors.black),
                        ),
                      ],
                    ),
                  ),

                  // Nội dung bài viết
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      content,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Color.fromARGB(255, 35, 52, 10),
                      ),
                    ),
                  ),

                  // Địa điểm (nếu có)
                  if (location.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              location,
                              style: const TextStyle(color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          )
                        ],
                      ),
                    ),
                  ],

                  // Ảnh bài viết
                  if (imageUrls.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SizedBox(
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
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
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
                    ),
                  ],
                  if (placeTags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
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
                    ),

                  // Footer với các nút tương tác
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 15, horizontal: 10),
                    child: StreamBuilder<DocumentSnapshot>(
                      stream: _firestore
                          .collection('posts')
                          .doc(postId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox();

                        final postData =
                            snapshot.data!.data() as Map<String, dynamic>;
                        final currentUser = FirebaseAuth.instance.currentUser;
                        final likedBy =
                            List<String>.from(postData['likedBy'] ?? []);
                        final likesCount = postData['likes'] ?? 0;
                        final isLiked = currentUser != null &&
                            likedBy.contains(currentUser.uid);

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            InkWell(
                              onTap: () async {
                                if (currentUser == null) return;

                                await _firestore
                                    .collection('posts')
                                    .doc(postId)
                                    .update({
                                  'likes':
                                      FieldValue.increment(isLiked ? -1 : 1),
                                  'likedBy': isLiked
                                      ? FieldValue.arrayRemove(
                                          [currentUser.uid])
                                      : FieldValue.arrayUnion(
                                          [currentUser.uid]),
                                });
                              },
                              child: Row(
                                children: [
                                  Icon(
                                    isLiked
                                        ? Icons.favorite
                                        : Icons.favorite_outline,
                                    color: isLiked
                                        ? Colors.red
                                        : const Color.fromARGB(
                                            255, 255, 12, 109),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(likesCount.toString()),
                                ],
                              ),
                            ),

                            // 💬 COMMENT
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        CommentScreen(postId: postId),
                                  ),
                                );
                              },
                              child: Row(
                                children: [
                                  Icon(Icons.comment_outlined,
                                      color: Constants.darkgreen),
                                  const SizedBox(width: 5),
                                  Text((postData['comments'] ?? 0).toString()),
                                ],
                              ),
                            ),

                            // 🔄 SHARE
                            InkWell(
                              onTap: () async {
                                try {
                                  await Share.share(
                                      'Xem bài viết này: $content');
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text("Lỗi khi chia sẻ bài viết")),
                                  );
                                }
                              },
                              child: Row(
                                children: [
                                  Icon(Icons.share_outlined,
                                      color: Constants.darkpp),
                                  const SizedBox(width: 5),
                                  Text((postData['shares'] ?? 0).toString()),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        });
  }
}
