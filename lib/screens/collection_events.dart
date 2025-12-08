import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CollectionEventsList extends StatelessWidget {
  const CollectionEventsList({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sự kiện sưu tầm')),
      body: StreamBuilder<QuerySnapshot>(
stream: FirebaseFirestore.instance
    .collection('collect_events')
    .where('category', isEqualTo: 'collection')
    .snapshots(),
        builder: (c, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('Không có sự kiện'));
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final d = docs[i];
              final data = d.data() as Map<String, dynamic>;
              final badge = data['badge'] as Map<String, dynamic>?;
              final ended = (data['endAt'] as Timestamp?)?.toDate().isBefore(DateTime.now()) ?? false;
              return ListTile(
                leading: badge != null && (badge['icon'] ?? '').toString().isNotEmpty
                    ? Image.network(badge['icon'], width: 48, height: 48, fit: BoxFit.cover)
                    : const Icon(Icons.emoji_events),
                title: Text(data['title'] ?? ''),
                subtitle: Text(data['description'] ?? ''),
                trailing: TextButton(
                  child: Text(ended ? 'Đã kết thúc' : 'Mở'),
                  onPressed: ended ? null : () => Navigator.pushNamed(context, '/event_collection', arguments: d.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}