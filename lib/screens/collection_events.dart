import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CollectionEventsList extends StatelessWidget {
  const CollectionEventsList({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  title: const Text(
    'Sự kiện sưu tầm',
    style: TextStyle(
      fontWeight: FontWeight.bold,
      color: Color(0xFF3B6332),
      fontSize: 18,
    ),
  ),
  centerTitle: true,
  backgroundColor: Colors.white,
  elevation: 0,
),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('collect_events')
            .where('category', isEqualTo: 'collection')
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
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Quay lại'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('Chưa có sự kiện nào',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aStart = (aData['startAt'] as Timestamp?)?.toDate();
            final bStart = (bData['startAt'] as Timestamp?)?.toDate();

            if (aStart == null && bStart == null) return 0;
            if (aStart == null) return 1;
            if (bStart == null) return -1;

            return bStart.compareTo(aStart);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final title = data['title'] ?? 'Không có tiêu đề';
              final description = data['description'] ?? '';
              final badge = data['badge'] as Map<String, dynamic>?;
              final badgeIcon = badge?['icon'] ?? '';

              final startAt = (data['startAt'] as Timestamp?)?.toDate();
              final endAt = (data['endAt'] as Timestamp?)?.toDate();
              final now = DateTime.now();

              final hasStarted = startAt != null && now.isAfter(startAt);
              final hasEnded = endAt != null && now.isAfter(endAt);
              final isActive = hasStarted && !hasEnded;

              Color statusColor;
              String statusText;
              IconData statusIcon;

              if (hasEnded) {
                statusColor = Colors.grey;
                statusText = 'Đã kết thúc';
                statusIcon = Icons.lock_clock;
              } else if (isActive) {
                statusColor = const Color(0xFF3B6332);
                statusText = 'Đang diễn ra';
                statusIcon = Icons.play_circle_filled;
              } else {
                statusColor = Colors.orange;
                statusText = 'Sắp diễn ra';
                statusIcon = Icons.schedule;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  // ✅ BỎ kiểm tra hasEnded => luôn cho phép mở
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/event_collection',
                    arguments: doc.id,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey[200],
                          ),
                          child: badgeIcon.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    badgeIcon,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                        Icons.emoji_events,
                                        size: 32),
                                  ),
                                )
                              : const Icon(Icons.emoji_events, size: 32),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF3B6332)
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              if (description.isNotEmpty)
                                Text(
                                  description,
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.grey[700]),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.access_time,
                                      size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '${_formatDate(startAt)} - ${_formatDate(endAt)}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600]),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 110,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: statusColor, width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(statusIcon,
                                        size: 14, color: statusColor),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        statusText,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: statusColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Icon(Icons.arrow_forward_ios,
                                  size: 16, color: const Color(0xFF3B6332)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '?';
    return '${date.day}/${date.month}/${date.year}';
  }
}
