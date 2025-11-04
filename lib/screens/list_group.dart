import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/svg.dart';
import 'package:stour/assets/icons/find_group_svg.dart';
import 'package:stour/screens/find_group.dart';
import '../assets/icons/chat_svg.dart';
import 'group_post.dart';

class GroupListScreen extends StatelessWidget {
  const GroupListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF4C6B36)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'TẤT CẢ NHÓM',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4C6B36),
                    ),
                  ),
                  IconButton(
                    icon: SvgPicture.string(findGroupSVG, height: 30, width: 30),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SearchGroupScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Danh sách nhóm
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('groups').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("Chưa có nhóm nào."));
                  }

                  final groups = snapshot.data!.docs;

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      final id = group.id;
                      final name = group['name'];
                      final members = group['members'] ?? [];
                      final membersCount = (members is List) ? members.length : 0;
                      final avatarUrl = group['avatarUrl'] ?? '';

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GroupPostScreen(groupId: id, groupName: name),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 32,
                                backgroundColor: const Color(0xFF9DB596),
                                backgroundImage: avatarUrl.isNotEmpty
                                    ? NetworkImage(avatarUrl)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          "$membersCount thành viên",
                                          style: const TextStyle(color: Colors.black54),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(Icons.info_outline, size: 14, color: Colors.green),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.remove_red_eye_outlined, color: Color(0xFF4C6B36)),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
