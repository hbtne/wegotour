import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'group_post.dart';

class SearchGroupScreen extends StatefulWidget {
  const SearchGroupScreen({super.key});

  @override
  State<SearchGroupScreen> createState() => _SearchGroupScreenState();
}

class _SearchGroupScreenState extends State<SearchGroupScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF3B6332);
    const Color avatarColor = Color(0xFFA3B49A);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 🔹 Thanh tìm kiếm
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: primaryColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() => _searchText = value.trim());
                      },
                      decoration: InputDecoration(
                        hintText: 'Nhập từ khóa để tìm kiếm',
                        prefixIcon: const Icon(Icons.search, color: primaryColor),
                        contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: primaryColor),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: primaryColor, width: 1.5),
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // 🔹 Tiêu đề
            const Text(
              'Kết quả tìm kiếm',
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),

            const SizedBox(height: 10),

            // 🔹 Danh sách nhóm
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('groups').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'Không tìm thấy nhóm nào',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  final allGroups = snapshot.data!.docs;

                  // 🔍 Lọc theo từ khóa (chứa)
                  final filteredGroups = _searchText.isEmpty
                      ? allGroups
                      : allGroups.where((doc) {
                    final name = (doc['name'] ?? '').toString().toLowerCase();
                    return name.contains(_searchText.toLowerCase());
                  }).toList();

                  if (filteredGroups.isEmpty) {
                    return const Center(
                      child: Text('Không tìm thấy nhóm nào'),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filteredGroups.length,
                    itemBuilder: (context, index) {
                      final group = filteredGroups[index];
                      final groupName = group['name'] ?? 'Tên nhóm';
                      final memberCount = (group['members'] as List?)?.length ?? 0;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8), // cho đẹp khi nhấn
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GroupPostScreen(groupId: group.id, groupName: groupName),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              // Avatar nhóm
                              Container(
                                width: 60,
                                height: 60,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFFA3B49A),
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Tên nhóm + thành viên
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      groupName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          '$memberCount thành viên',
                                          style: const TextStyle(
                                            color: Colors.black87,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.info_outline,
                                          size: 15,
                                          color: Color(0xFF3B6332),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Icon con mắt
                              const Icon(Icons.remove_red_eye, color: Color(0xFF3B6332)),
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
