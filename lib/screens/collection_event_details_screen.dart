import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

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
                  title: Text(title, style: const TextStyle(fontSize: 18)),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.blue.shade400, Colors.purple.shade400],
                      ),
                    ),
                    child: Center(
                      child: badge != null &&
                              badge['icon'] != null &&
                              badge['icon'].toString().isNotEmpty
                          ? Image.network(
                              badge['icon'],
                              height: 100,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.emoji_events,
                                  size: 80,
                                  color: Colors.white),
                            )
                          : const Icon(Icons.emoji_events,
                              size: 80, color: Colors.white),
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
                    children: [
                      // Mô tả
                      Text(description, style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 16),

                      // Keywords
                      if (keywords.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: keywords
                              .map((kw) => Chip(
                                    avatar: const Icon(Icons.search, size: 16),
                                    label: Text(kw),
                                    backgroundColor: Colors.blue.shade50,
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
                                const Icon(Icons.timer, color: Colors.orange),
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
                      if (hasEnded)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black,
                              minimumSize: const Size(double.infinity, 50),
                            ),
                            icon: const Icon(Icons.emoji_events),
                            label: const Text('🎖️ Cấp huy hiệu ngay'),
onPressed: () async {
  print('========================================');
  print('🔥 BADGE AWARD BUTTON PRESSED');
  print('========================================');

  // Check 1: User authentication
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('❌ Bạn cần đăng nhập để cấp huy hiệu!'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  // Show loading
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    // 🔥 CALLABLE FUNCTION
    final callable = FirebaseFunctions.instance
        .httpsCallable('manualAwardBadges');

    final result = await callable.call({
      'eventId': widget.eventId,
    });

    Navigator.pop(context); // Close loading

    final awarded = result.data['awarded'] ?? 0;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('🎉 Đã cấp huy hiệu cho $awarded người!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  } on FirebaseFunctionsException catch (e) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ Lỗi Functions: ${e.message}'),
        backgroundColor: Colors.red,
      ),
    );
  } catch (e) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ Lỗi: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

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
                    labelColor: Theme.of(context).primaryColor,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Theme.of(context).primaryColor,
                    tabs: const [
                      Tab(icon: Icon(Icons.feed), text: 'Bài đăng'),
                      Tab(icon: Icon(Icons.leaderboard), text: 'Bảng xếp hạng'),
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
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('collect_events')
          .doc(eventId)
          .collection('submissions')
          .where('isValid', isEqualTo: true)
          // ✅ FIX 1: Bỏ orderBy để tránh lỗi index
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

        // ✅ FIX 2: Sort trên client side
        submissions.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = (aData['createdAt'] as Timestamp?)?.toDate();
          final bTime = (bData['createdAt'] as Timestamp?)?.toDate();

          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;

          return bTime.compareTo(aTime); // Mới nhất trước
        });

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: submissions.length,
          itemBuilder: (context, index) {
            final doc = submissions[index];
            final data = doc.data() as Map<String, dynamic>;

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
                          icon: Icons.favorite_border,
                          count: data['likes'] ?? 0,
                          onTap: () => _likeSubmission(eventId, doc.id),
                        ),
                        const SizedBox(width: 16),
                        _buildInteractionButton(
                          icon: Icons.comment_outlined,
                          count: data['comments'] ?? 0,
                          onTap: () {
                            // TODO: Implement comments
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Tính năng comment đang phát triển')),
                            );
                          },
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
          // ✅ FIX 3: Bỏ orderBy, sort trên client
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

        // ✅ FIX 4: Sort trên client side
        entries.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aScore = aData['totalScore'] ?? 0;
          final bScore = bData['totalScore'] ?? 0;
          return bScore.compareTo(aScore); // Điểm cao nhất trước
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
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 4),
            Text('$count'),
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
      // TODO: Implement proper like system với check duplicate
      // Hiện tại chỉ increment trực tiếp
      await FirebaseFirestore.instance
          .collection('collect_events')
          .doc(eventId)
          .collection('submissions')
          .doc(submissionId)
          .update({
        'likes': FieldValue.increment(1),
        'score': FieldValue.increment(1),
      });

      // Update leaderboard (optional - nếu có Cloud Function thì không cần)
      final submission = await FirebaseFirestore.instance
          .collection('collect_events')
          .doc(eventId)
          .collection('submissions')
          .doc(submissionId)
          .get();

      if (submission.exists) {
        final userId = submission.data()?['userId'];
        if (userId != null) {
          await FirebaseFirestore.instance
              .collection('collect_events')
              .doc(eventId)
              .collection('leaderboard')
              .doc(userId)
              .update({
            'totalScore': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi like: $e')),
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
