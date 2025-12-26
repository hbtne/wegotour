import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:stour/screens/profile.dart';

import '../screens/addPost_screen.dart';
import '../screens/comment_screen.dart';
import '../screens/group_post.dart';
import '../util/const.dart';

class PostItem extends StatefulWidget {
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
  final String? highlightCommentId;
  final bool isLiked;

  const PostItem({
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
    required this.avatar,
    this.highlightCommentId,
    required this.isLiked,
  });

  @override
  State<PostItem> createState() => _PostItemState();
}

class _PostItemState extends State<PostItem> {
  static final _firestore = FirebaseFirestore.instance;
  late Future<List<Map<String, dynamic>>> _placesFuture;
  Map<String, String>? _selectedBadge;

  @override
  void initState() {
    super.initState();
    _placesFuture = _fetchPlacesFromIds(widget.placeIds);
    _fetchSelectedBadge();
  }

  Future<List<Map<String, dynamic>>> _fetchPlacesFromIds(
      List<String> placeIds) async {
    if (placeIds.isEmpty) return [];

    final query = await _firestore
        .collection('places')
        .where(FieldPath.documentId, whereIn: placeIds.take(10).toList())
        .get();

    return query.docs.map((e) => {...e.data(), 'id': e.id}).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _placesFuture,
      builder: (context, snapshot) {
        final placeTags = snapshot.data ?? [];

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              _buildContent(),
              if (widget.location.isNotEmpty) _buildLocation(),
              if (widget.imageUrls.isNotEmpty) _buildImages(),
              if (placeTags.isNotEmpty) _buildPlaceTags(placeTags),
              _buildFooter(context),
            ],
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
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Profile(
                          profileId: widget.authorId,
                        ),
                      ),
                    );
                  },
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: widget.avatar.isNotEmpty
                        ? NetworkImage(widget.avatar)
                        : const AssetImage('assets/default_avatar.png')
                            as ImageProvider,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => Profile(
                                  profileId: widget.authorId,
                                ),
                              ),
                            );
                          },
                          child: Text(
                            widget.author,
                            style: const TextStyle(
                              color: Color(0xFF2E5E2A),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        if (widget.groupId.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => GroupPostScreen(
                                    groupId: widget.groupId,
                                    groupName: widget.groupName,
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
                                  widget.groupName,
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

                    if (_selectedBadge != null &&
                        (_selectedBadge!['icon'] ?? '').isNotEmpty)
                      Row(
                        children: [
                          ClipOval(
                            child: Image.network(
                              _selectedBadge!['icon']!,
                              width: 18,
                              height: 18,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.emoji_events,
                                size: 14,
                                color: Colors.amber,
                              ),
                            ),
                          ),
                          if (_selectedBadge!['name']?.isNotEmpty ?? false)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Text(
                                _selectedBadge!['name']!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF2E5E2A),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),

                    // ===== TIME =====
                    if (_selectedBadge != null &&
                        (_selectedBadge!['icon'] ?? '').isNotEmpty)
                      const SizedBox(height: 2),
                    Text(
                      _getTimeAgo(widget.timeAgo),
                      style: const TextStyle(
                        color: Color.fromARGB(173, 35, 52, 10),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            PopupMenuButton<String>(
              onSelected: (v) => _handleMenu(context, v),
              itemBuilder: (_) => const [
                PopupMenuItem(value: "edit", child: Text("Chỉnh sửa")),
                PopupMenuItem(value: "delete", child: Text("Xóa")),
              ],
            ),
          ],
        ));
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        widget.content,
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
          const SizedBox(width: 10),
          Text(
            widget.location,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.grey, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildImages() {
    return SizedBox(
      height: 250,
      child: PageView.builder(
        itemCount: widget.imageUrls.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                widget.imageUrls[index],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
              overflow: TextOverflow.ellipsis,
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
                widget.isLiked
                    ? const Icon(Icons.favorite, color: Colors.red)
                    : const Icon(Icons.favorite_outline,
                        color: Color.fromARGB(255, 255, 12, 109)),
                const SizedBox(width: 5),
                Text(widget.likes.toString()),
              ],
            ),
          ),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CommentScreen(postId: widget.postId),
                ),
              );
            },
            child: Row(
              children: [
                Icon(Icons.comment_outlined, color: Constants.darkgreen),
                const SizedBox(width: 5),
                Text(widget.comments.toString()),
              ],
            ),
          ),
          InkWell(
            onTap: () => _handleShare(context),
            child: Row(
              children: [
                Icon(Icons.share_outlined, color: Constants.darkpp),
                const SizedBox(width: 5),
                Text(widget.shares.toString()),
              ],
            ),
          )
        ],
      ),
    );
  }

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
          await _firestore.collection('posts').doc(widget.postId).delete();

          if (widget.authorId.isNotEmpty) {
            final userRef = _firestore.collection('users').doc(widget.authorId);
            await userRef.update({
              'posts': FieldValue.arrayRemove([widget.postId]),
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
        'content': widget.content,
        'location': widget.location,
        'imageUrls': widget.imageUrls,
      };

      final updated = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => AddPostScreen(
            existingPost: currentPostData,
            postId: widget.postId,
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final postRef = _firestore.collection('posts').doc(widget.postId);

    await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(postRef);
      final likedBy = List<String>.from(snap['likedBy'] ?? []);

      if (!likedBy.contains(user.uid)) {
        transaction.update(postRef, {
          'likes': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([user.uid]),
        });
      }
    });
  }

  Future<void> _handleShare(BuildContext context) async {
    await Share.share(widget.content);

    await _firestore.collection('posts').doc(widget.postId).update({
      'shares': FieldValue.increment(1),
    });
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

  Future<void> _fetchSelectedBadge() async {
    try {
      final userDoc =
          await _firestore.collection('users').doc(widget.authorId).get();

      final selectedBadgeId = userDoc.data()?['selectedBadge'];
      if (selectedBadgeId == null || selectedBadgeId.toString().isEmpty) return;

      final badgesSnapshot = await _firestore
          .collection('users')
          .doc(widget.authorId)
          .collection('badges')
          .get();

      final matchingDoc = badgesSnapshot.docs.firstWhere(
        (doc) => doc.id.endsWith(selectedBadgeId),
        orElse: () => throw Exception('Badge not found'),
      );

      final data = matchingDoc.data();

      setState(() {
        _selectedBadge = {
          'icon': data['icon'] ?? '',
          'name': data['name'] ?? '',
        };
      });
    } catch (e) {
      print('Error fetching badge: $e');
    }
  }
}
