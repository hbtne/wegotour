import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stour/assets/icons/bio_svg.dart' as BioIcon;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:stour/assets/icons/key_w_svg.dart' as KeyWIcon;
import 'package:share_plus/share_plus.dart';

class CollectionEventDetailScreen extends StatefulWidget {
  final String eventId;

  const CollectionEventDetailScreen({super.key, required this.eventId});

  @override
  State<CollectionEventDetailScreen> createState() =>
      _CollectionEventDetailScreenState();
}

class _CollectionEventDetailScreenState
    extends State<CollectionEventDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('collect_events')
            .doc(widget.eventId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Event không tồn tại'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Quay lại'),
                  ),
                ],
              ),
            );
          }

          final eventData = snapshot.data!.data() as Map<String, dynamic>;
          final title = eventData['title'] ?? '';
          final description = eventData['description'] ?? '';
          final keywords = List<String>.from(eventData['keywords'] ?? []);
          final badge = eventData['badge'] as Map<String, dynamic>?;
          final endAt = (eventData['endAt'] as Timestamp?)?.toDate();
          final hasEnded = endAt != null && DateTime.now().isAfter(endAt);

          return CustomScrollView(
            slivers: [
              // App Bar với background
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Color(0xFF3B6332),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color.fromARGB(255, 160, 160, 160),
                          Color.fromARGB(255, 237, 237, 232),
                        ],
                      ),
                    ),
                    child: Center(
                      child: badge != null &&
                              badge['icon'] != null &&
                              badge['icon'].toString().isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: Image.network(
                                badge['icon'],
                                height: 100,
                                width: 100,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 100,
                                  width: 100,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: const Icon(
                                    Icons.emoji_events,
                                    size: 64,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              height: 100,
                              width: 100,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.emoji_events,
                                size: 64,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ),

              // Thông tin event
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:[
                      // Mô tả
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                         SvgPicture.string(BioIcon.bioSVG, height: 20, width: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              description,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Keywords
                      if (keywords.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          
                          children: keywords
                              .map((kw) => Chip(
                                    avatar: SvgPicture.string(KeyWIcon.keyWSVG, height: 20, width: 20),
                                    label: Text(kw),
                                    backgroundColor: const Color(0xFF3B6332).withOpacity(0.1),
                  
                                  ))
                              .toList(),
                        ),
                      const SizedBox(height: 16),

                      // Thời gian còn lại
                      if (!hasEnded && endAt != null)
                        Card(
                          color: Colors.orange.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                const Icon(Icons.timer, color: Color.fromARGB(255, 209, 102, 100)),
                                const SizedBox(width: 8),
                                Text(
                                  'Còn ${_calculateTimeLeft(endAt)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),

                      if (hasEnded)
                        Card(
                          color: Colors.grey.shade200,
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(Icons.lock_clock, color: Colors.grey),
                                SizedBox(width: 8),
                                Text('Sự kiện đã kết thúc',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Tabs
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverAppBarDelegate(
                  TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFF3B6332),
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: const Color(0xFF3B6332),
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.feed, color: Color(0xFF3B6332)),
                        child: Text('Bài đăng', style: TextStyle(color: Color(0xFF3B6332))),
                      ),
                      Tab(
                        icon: Icon(Icons.leaderboard, color: Color(0xFF3B6332)),
                        child: Text('Bảng xếp hạng', style: TextStyle(color: Color(0xFF3B6332))),
                      ),
                    ],
                  ),
                ),
              ),

              // Tab content
              SliverFillRemaining(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSubmissionsFeed(widget.eventId),
                    _buildLeaderboard(widget.eventId),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('collect_events')
            .doc(widget.eventId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const SizedBox.shrink();
          }

          final eventData = snapshot.data!.data() as Map<String, dynamic>;
          final endAt = (eventData['endAt'] as Timestamp?)?.toDate();
          final hasEnded = endAt != null && DateTime.now().isAfter(endAt);

          if (hasEnded) return const SizedBox.shrink();

          return FloatingActionButton.extended(
            onPressed: () =>
                _showSubmissionDialog(context, widget.eventId, eventData),
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text('Đăng bài'),
          );
        },
      ),
    );
  }

  Widget _buildSubmissionsFeed(String eventId) {
    final user = FirebaseAuth.instance.currentUser;
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('collect_events')
          .doc(eventId)
          .collection('submissions')
          .where('isValid', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Lỗi: ${snapshot.error}'),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final submissions = snapshot.data!.docs;

        if (submissions.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Chưa có bài đăng nào',
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
          );
        }

        // Sort client side by createdAt desc
        submissions.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = (aData['createdAt'] as Timestamp?)?.toDate();
          final bTime = (bData['createdAt'] as Timestamp?)?.toDate();

          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;

          return bTime.compareTo(aTime);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: submissions.length,
          itemBuilder: (context, index) {
            final doc = submissions[index];
            final data = doc.data() as Map<String, dynamic>;
            final likedBy = List<String>.from(data['likedBy'] ?? []);
            final hasLiked = user != null && likedBy.contains(user.uid);

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User info
                  ListTile(
                    leading: CircleAvatar(
                      backgroundImage: data['userAvatar'] != null &&
                              data['userAvatar'].toString().isNotEmpty
                          ? NetworkImage(data['userAvatar'])
                          : null,
                      child: data['userAvatar'] == null ||
                              data['userAvatar'].toString().isEmpty
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(data['userName'] ?? 'Unknown'),
                    subtitle:
                        Text(_formatTimestamp(data['createdAt'] as Timestamp?)),
                  ),

                  // Image
                  if (data['imageUrl'] != null &&
                      data['imageUrl'].toString().isNotEmpty)
                    Image.network(
                      data['imageUrl'],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 200,
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.broken_image,
                              size: 64, color: Colors.grey),
                        ),
                      ),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 200,
                          color: Colors.grey[200],
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),

                  // Caption
                  if (data['caption'] != null &&
                      data['caption'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(data['caption']),
                    ),

                  // Interactions
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        _buildInteractionButton(
                          icon: hasLiked ? Icons.favorite : Icons.favorite_border,
                          count: (data['likes'] ?? 0) as int,
                          onTap: hasLiked ? null : () => _likeSubmission(eventId, doc.id),
                          color: hasLiked ? Colors.red : null,
                        ),
                        const SizedBox(width: 16),
                        _buildInteractionButton(
                          icon: Icons.comment_outlined,
                          count: (data['comments'] ?? 0) as int,
                          onTap: () => _showCommentsDialog(eventId, doc.id, data),
                        ),
                        const SizedBox(width: 16),
                        _buildInteractionButton(
                          icon: Icons.share_outlined,
                          count: (data['shares'] ?? 0) as int,
                          onTap: () => _shareSubmission(eventId, doc.id, data),
                        ),
                        const Spacer(),
                        Text(
                          '${data['score'] ?? 0} điểm',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLeaderboard(String eventId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('collect_events')
          .doc(eventId)
          .collection('leaderboard')
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Lỗi: ${snapshot.error}'),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final entries = snapshot.data!.docs;

        if (entries.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Chưa có người tham gia',
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
          );
        }

        // Sort client side by totalScore desc
        entries.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aScore = aData['totalScore'] ?? 0;
          final bScore = bData['totalScore'] ?? 0;
          return bScore.compareTo(aScore);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final data = entries[index].data() as Map<String, dynamic>;
            final rank = index + 1;

            Color? rankColor;
            IconData? rankIcon;
            if (rank == 1) {
              rankColor = Colors.amber;
              rankIcon = Icons.emoji_events;
            } else if (rank == 2) {
              rankColor = Colors.grey[400];
              rankIcon = Icons.emoji_events;
            } else if (rank == 3) {
              rankColor = Colors.brown[300];
              rankIcon = Icons.emoji_events;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: rank <= 3 ? 4 : 1,
              child: ListTile(
                leading: rankIcon != null
                    ? Icon(rankIcon, color: rankColor, size: 32)
                    : CircleAvatar(child: Text('#$rank')),
                title: Text(
                  data['userName'] ?? 'Unknown',
                  style: TextStyle(
                    fontWeight: rank <= 3 ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Text('${data['submissionCount'] ?? 0} bài đăng'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${data['totalScore'] ?? 0}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: rank <= 3 ? rankColor : Colors.blue,
                      ),
                    ),
                    const Text('điểm', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInteractionButton({
    required IconData icon,
    required int count,
    VoidCallback? onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 4),
            Text('$count', style: TextStyle(color: color)),
          ],
        ),
      ),
    );
  }

  Future<void> _likeSubmission(String eventId, String submissionId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn cần đăng nhập để like')),
      );
      return;
    }

    try {
      // Check if already liked
      final submissionDoc = await FirebaseFirestore.instance
          .collection('collect_events')
          .doc(eventId)
          .collection('submissions')
          .doc(submissionId)
          .get();

      if (!submissionDoc.exists) return;

      final likedBy = List<String>.from(submissionDoc.data()?['likedBy'] ?? []);
      
      if (likedBy.contains(user.uid)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bạn đã like bài này rồi')),
        );
        return;
      }

      // Add like
      await FirebaseFirestore.instance
          .collection('collect_events')
          .doc(eventId)
          .collection('submissions')
          .doc(submissionId)
          .update({
        'likes': FieldValue.increment(1),
        'score': FieldValue.increment(1),
        'likedBy': FieldValue.arrayUnion([user.uid]),
      });

      // Update leaderboard
      final submission = submissionDoc.data();
      final userId = submission?['userId'];
      final userName = submission?['userName'];
      if (userId != null) {
        await FirebaseFirestore.instance
            .collection('collect_events')
            .doc(eventId)
            .collection('leaderboard')
            .doc(userId)
            .set({
          'userName': userName ?? 'Unknown',
          'totalScore': FieldValue.increment(1),
          'submissionCount': FieldValue.increment(0),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi like: $e')),
        );
      }
    }
  }

  Future<void> _showCommentsDialog(
      String eventId, String submissionId, Map<String, dynamic> submissionData) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn cần đăng nhập để xem bình luận')),
      );
      return;
    }

    final commentController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'Bình luận',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              
              // Comments list
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('collect_events')
                      .doc(eventId)
                      .collection('submissions')
                      .doc(submissionId)
                      .collection('comments')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text('Chưa có bình luận nào',
                            style: TextStyle(color: Colors.grey)),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final commentDoc = snapshot.data!.docs[index];
                        final comment = commentDoc.data() as Map<String, dynamic>;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: comment['userAvatar'] != null &&
                                    comment['userAvatar'].toString().isNotEmpty
                                ? NetworkImage(comment['userAvatar'])
                                : null,
                            child: comment['userAvatar'] == null ||
                                    comment['userAvatar'].toString().isEmpty
                                ? const Icon(Icons.person, size: 20)
                                : null,
                          ),
                          title: Text(comment['userName'] ?? 'Unknown',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(comment['comment'] ?? ''),
                              const SizedBox(height: 4),
                              Text(
                                _formatTimestamp(comment['createdAt'] as Timestamp?),
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              const Divider(),
              
              // Comment input
              Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: commentController,
                        decoration: const InputDecoration(
                          hintText: 'Viết bình luận...',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () async {
                        if (commentController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Vui lòng nhập bình luận')),
                          );
                          return;
                        }

                        try {
                          // Add comment
                          await FirebaseFirestore.instance
                              .collection('collect_events')
                              .doc(eventId)
                              .collection('submissions')
                              .doc(submissionId)
                              .collection('comments')
                              .add({
                            'userId': user.uid,
                            'userName': user.displayName ?? 'Unknown',
                            'userAvatar': user.photoURL ?? '',
                            'comment': commentController.text.trim(),
                            'createdAt': FieldValue.serverTimestamp(),
                          });

                          // Update submission: +1 comment, +2 score
                          await FirebaseFirestore.instance
                              .collection('collect_events')
                              .doc(eventId)
                              .collection('submissions')
                              .doc(submissionId)
                              .update({
                            'comments': FieldValue.increment(1),
                            'score': FieldValue.increment(2),
                          });

                          // Update leaderboard
                          final authorId = submissionData['userId'];
                          final authorName = submissionData['userName'];
                          if (authorId != null) {
                            await FirebaseFirestore.instance
                                .collection('collect_events')
                                .doc(eventId)
                                .collection('leaderboard')
                                .doc(authorId)
                                .set({
                              'userName': authorName ?? 'Unknown',
                              'totalScore': FieldValue.increment(2),
                              'submissionCount': FieldValue.increment(0),
                              'updatedAt': FieldValue.serverTimestamp(),
                            }, SetOptions(merge: true));
                          }

                          commentController.clear();
                          
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Đã bình luận (+2 điểm)')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Lỗi: $e')),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareSubmission(
      String eventId, String submissionId, Map<String, dynamic> submissionData) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn cần đăng nhập để chia sẻ')),
      );
      return;
    }

    try {
      final shareText = '''
Xem bài thi của ${submissionData['userName'] ?? 'Unknown'}
${submissionData['caption'] ?? ''}
Điểm: ${submissionData['score'] ?? 0}
      ''';

      await Share.share(shareText);

      // Update submission: +1 share, +3 score
      await FirebaseFirestore.instance
          .collection('collect_events')
          .doc(eventId)
          .collection('submissions')
          .doc(submissionId)
          .update({
        'shares': FieldValue.increment(1),
        'score': FieldValue.increment(3),
      });

      // Update leaderboard
      final authorId = submissionData['userId'];
      final authorName = submissionData['userName'];
      if (authorId != null) {
        await FirebaseFirestore.instance
            .collection('collect_events')
            .doc(eventId)
            .collection('leaderboard')
            .doc(authorId)
            .set({
          'userName': authorName ?? 'Unknown',
          'totalScore': FieldValue.increment(3),
          'submissionCount': FieldValue.increment(0),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã chia sẻ (+3 điểm)')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi chia sẻ: $e')),
        );
      }
    }
  }

  void _showSubmissionDialog(
      BuildContext context, String eventId, Map<String, dynamic> eventData) {
    Navigator.pushNamed(
      context,
      '/event_submit',
      arguments: {
        'eventId': eventId,
        'keywords': eventData['keywords'] ?? [],
      },
    );
  }

  String _calculateTimeLeft(DateTime endDate) {
    final diff = endDate.difference(DateTime.now());
    if (diff.inDays > 0) return '${diff.inDays} ngày';
    if (diff.inHours > 0) return '${diff.inHours} giờ';
    if (diff.inMinutes > 0) return '${diff.inMinutes} phút';
    return 'Sắp hết hạn';
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 0) return '${diff.inDays} ngày trước';
    if (diff.inHours > 0) return '${diff.inHours} giờ trước';
    if (diff.inMinutes > 0) return '${diff.inMinutes} phút trước';
    return 'Vừa xong';
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}