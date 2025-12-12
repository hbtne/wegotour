import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BadgeCabinet extends StatelessWidget {
  final String userId;
  const BadgeCabinet({required this.userId, super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return CircularProgressIndicator();
        final data = snap.data!.data() as Map<String, dynamic>? ?? {};
        final badges = List<String>.from(data['badges'] ?? []);
        final selected = data['selectedBadge'];
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
          itemCount: badges.length,
          itemBuilder: (context, i) {
            final id = badges[i];
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('badges').doc(id).get(),
              builder: (c, s) {
                if (!s.hasData) return SizedBox();
                final b = s.data!.data() as Map<String, dynamic>;
                return GestureDetector(
                  onTap: () => FirebaseFirestore.instance.collection('users').doc(userId).update({'selectedBadge': id}),
                  child: Column(
                    children: [
                      Image.network(b['iconUrl'] ?? '', width: 64, height: 64),
                      Text(b['title'] ?? ''),
                      if (selected == id) Text('Đang hiển thị', style: TextStyle(fontSize: 10, color: Colors.green))
                    ],
                  ),
                );
              }
            );
          });
      }
    );
  }
}