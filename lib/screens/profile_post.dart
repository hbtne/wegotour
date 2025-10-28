import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:stour/util/const.dart';

import 'addPost_screen.dart';
import 'comment_screen.dart';

class PostScreen extends StatefulWidget {
  const PostScreen({super.key});

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> _fetchPlacesFromIds(List<String> placeIds) async {
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
      stream: _firestore.collection('posts').orderBy('createdAt', descending: true).snapshots(),
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
            final postId = postData.id;
            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('users').doc(authorId).get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox();
                }
                if (userSnapshot.hasError || !userSnapshot.hasData || !userSnapshot.data!.exists) {

                  final placeIds = List<String>.from(data['places'] ?? []);
                  return _buildPostItem(
                    postId: postId,
                    content: data['content'] ?? '',
                    imageUrls: List<String>.from(data['imageUrls'] ?? []),
                    author: 'Người dùng ẩn danh',
                    timeAgo: _getTimeAgo(data['createdAt'] as Timestamp),
                    location: data['location'] ?? '',
                    avatarUrl: '',
                    likes: data['likes'] ?? 0,
                    comments: data['comments'] ?? 0,
                    shares: data['shares']??0,
                    authorId: authorId,
                    placeIds: placeIds,
                  );
                }
                final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                final placeIds = List<String>.from(data['places'] ?? []);
                return _buildPostItem(
                  postId: postId,
                  content: data['content'] ?? '',
                  imageUrls: List<String>.from(data['imageUrls'] ?? []),
                  author: userData['username'] ?? 'Không tên',
                  timeAgo: _getTimeAgo(data['createdAt'] as Timestamp),
                  location: data['location'] ?? '',
                  avatarUrl: userData['avatar'] ?? '',
                  likes: data['likes'] ?? 0,
                  comments: data['comments'] ?? 0,
                  shares: data['shares']??0,
                  authorId: authorId,
                  placeIds: placeIds,
                );
              },
            );

          },
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

  Widget _buildPostItem({
    required String postId,
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
    required List<String> placeIds

  }) {
    return FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchPlacesFromIds(placeIds),
    builder: (context, snapshot) {
    final places = snapshot.data ?? [];
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
        : const AssetImage('assets/default_avatar.png') as ImageProvider,
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
    // 1. Xóa bài viết trong posts
    await FirebaseFirestore.instance.collection('posts').doc(postId).delete();

    // 2. Cập nhật document user để xóa postId trong mảng posts
    if (authorId.isNotEmpty) {
    final userRef = FirebaseFirestore.instance.collection('users').doc(authorId);
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
    }
    else if (value == "edit") {
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
    child: const Icon(Icons.more_vert, color: Colors.black),
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
    const Icon(Icons.location_on, size: 16, color: Colors.grey),
    const SizedBox(width: 5),
    Text(
    location,
    style: const TextStyle(color: Colors.grey),
    ),
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
    ),
    ],
      if (placeTags.isNotEmpty)
        Padding(
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
        ),

      // Footer với các nút tương tác
    Padding(
    padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
    child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
    InkWell(
    onTap: () async {
    final currentUser = FirebaseAuth.instance.currentUser; // Lấy người dùng hiện tại
    if (currentUser == null) {
    // Nếu chưa đăng nhập, không cho thả like
    return;
    }

    final postRef = _firestore.collection('posts').doc(postId);
    final postDoc = await postRef.get();

    // Kiểm tra xem người dùng đã thả like chưa
    List<dynamic> likedBy = postDoc['likedBy'] ?? [];
    if (!likedBy.contains(currentUser.uid)) {
    // Nếu chưa thả like, cho phép thả like
    await postRef.update({
    'likes': FieldValue.increment(1), // Tăng số lượt thích
    'likedBy': FieldValue.arrayUnion([currentUser.uid]), // Thêm userId vào mảng likedBy
    });
    } else {
    // Nếu đã thả like rồi, thông báo cho người dùng biết
    ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text("Bạn đã thả like bài viết này")),
    );
    }
    },
    child: Row(
    children: [
    const Icon(Icons.favorite_outline, color: Color.fromARGB(255, 255, 12, 109)),
    const SizedBox(width: 5),
    Text(likes.toString()), // Hiển thị số lượt thích
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
    onTap: () async {
    try {
    final currentUser = FirebaseAuth.instance.currentUser; // Lấy người dùng hiện tại
    if (currentUser == null) {
    return;
    }

    // Chia sẻ nội dung bài viết
    await Share.share('Xem bài viết này: $content');
    } catch (e) {
    print("Error sharing post: $e"); // In lỗi ra console
    ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text("Đã xảy ra lỗi khi chia sẻ bài viết.")),
    );
    }
    },
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
    ),
    ],
    ),
    ),
    );
    });
  }

}