import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:stour/services/auth_service.dart';
import 'package:stour/widgets/item_post.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  final String? highlightCommentId;

  const PostDetailScreen({
    super.key,
    required this.postId,
    this.highlightCommentId,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Map<String, dynamic>? post;
  Map<String, dynamic>? user;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _highlightKey = GlobalKey();

  bool _scrolled = false; // tránh scroll lại nhiều lần
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final postSnap = await FirebaseFirestore.instance
        .collection("posts")
        .doc(widget.postId)
        .get();

    if (!postSnap.exists) return;

    final postData = postSnap.data()!;
    final userId = postData['authorId'];

    final userSnap = await FirebaseFirestore.instance
        .collection("users")
        .doc(userId)
        .get();

    setState(() {
      post = postData;
      user = userSnap.data();
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = const Color(0xFF4A5C3B);

    if (post == null || user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final currentUid = AuthService.getCurrentUserId();
    final isLiked = currentUid != null &&
        List<String>.from(post!['likedBy'] ?? []).contains(currentUid);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primary),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'BÀI VIẾT CỦA BẠN',
          style: TextStyle(
            color: primary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PostItem(
              postId: widget.postId,
              groupId: post!['groupId'] ?? '',
              groupName: post!['groupName'] ?? '',
              content: post!['content'] ?? '',
              imageUrls: List<String>.from(post!['imageUrls'] ?? []),
              timeAgo: post!['createdAt'] as Timestamp,
              location: post!['location'] ?? '',
              likes: post!['likes'] ?? 0,
              comments: post!['comments'] ?? 0,
              shares: post!['shares'] ?? 0,
              authorId: post!['authorId'],
              placeIds: List<String>.from(post!['places'] ?? []),
              author: user!['username'] ?? 'Ẩn danh',
              avatar: user!['avatar'] ?? '',
              highlightCommentId: widget.highlightCommentId,
              isLiked: isLiked,
            ),

            _buildComments(), // ⭐ DANH SÁCH BÌNH LUẬN
          ],
        ),
      ),
    );
  }

  Widget _buildComments() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("comments")
          .where("post", isEqualTo: widget.postId)
          .orderBy("time", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          );
        }

        final docs = snapshot.data!.docs;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scrolled &&
              widget.highlightCommentId != null &&
              _highlightKey.currentContext != null) {
            _scrolled = true;

            Scrollable.ensureVisible(
              _highlightKey.currentContext!,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              alignment: 0.2,
            );
          }
        });

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: docs.map((doc) {
              final isHighlight =
                  doc.id == widget.highlightCommentId;

              return CommentItem(
                key: isHighlight ? _highlightKey : null,
                doc: doc,
                highlight: isHighlight,
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class CommentItem extends StatelessWidget {
  final DocumentSnapshot doc;
  final bool highlight;

  const CommentItem({
    super.key,
    required this.doc,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final Color primary = const Color(0xFF4A5C3B);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight
            ? Colors.orangeAccent.shade100
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight ? primary : Colors.grey.shade200,
          width: highlight ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: data['avatar'] != null && data['avatar'] != ''
              ? NetworkImage(data['avatar'])
              : const AssetImage('assets/default_avatar.png') as ImageProvider,
        ),
        title: Text(data['username'] ?? 'Ẩn danh', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),),
        subtitle: Text(data['value'] ?? 'Không có nội dung', style: TextStyle(fontSize: 13),),
        trailing: Text(
          _getTimeAgo(data['time'] as Timestamp),
          style: const TextStyle(fontSize: 12),
        ),
      )
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
}
