import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:stour/screens/group_message.dart';

class SearchMessageScreen extends StatefulWidget {
  const SearchMessageScreen({super.key});

  @override
  State<SearchMessageScreen> createState() => _SearchMessageScreenState();
}

class _SearchMessageScreenState extends State<SearchMessageScreen> {
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔹 Thanh tìm kiếm
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF48623F)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: "Nhập từ khóa tin nhắn...",
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF48623F)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: const BorderSide(color: Color(0xFF48623F)),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value.trim();
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              const Center(
                child: Text(
                  "Kết quả tìm kiếm",
                  style: TextStyle(
                    color: Color(0xFF48623F),
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: searchQuery.isEmpty
                    ? const Center(child: Text("Nhập từ khóa để tìm tin nhắn"))
                    : FutureBuilder<List<Map<String, dynamic>>>(
                  future: _searchMessages(searchQuery),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text("Không tìm thấy tin nhắn nào"));
                    }

                    final results = snapshot.data!;
                    return ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final item = results[index];
                        return _buildMessageTile(
                          groupId: item['groupId'],
                          avatarUrl: item['avatarUrl'],
                          groupName: item['groupName'],
                          messageText: item['text'],
                          highlight: searchQuery,
                          context: context,
                          createAt: item['createAt'],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 🔍 Tìm kiếm tin nhắn có chứa keyword trong tất cả nhóm
  Future<List<Map<String, dynamic>>> _searchMessages(String keyword) async {
    final lowerKeyword = keyword.trim().toLowerCase();
    if (lowerKeyword.isEmpty) return [];

    final groupsSnapshot = await FirebaseFirestore.instance.collection('groups').get();
    List<Map<String, dynamic>> results = [];

    for (var group in groupsSnapshot.docs) {
      final messagesSnapshot = await group.reference
          .collection('messages')
          .orderBy('createAt', descending: true)
          .limit(100) // tránh load quá nhiều
          .get();

      for (var group in groupsSnapshot.docs) {
        final messagesSnapshot = await group.reference.collection('messages').get();
        debugPrint("🔹 Nhóm ${group['name']} có ${messagesSnapshot.docs.length} tin nhắn.");

        for (var msg in messagesSnapshot.docs) {
          final text = (msg['text'] ?? '').toString();

          if (text.trim().toLowerCase().contains(lowerKeyword)) {
            results.add({
              'groupId': group.id,
              'avatarUrl': group['avatarUrl'] ?? '',
              'groupName': group['name'] ?? '',
              'text': text,
              'createAt': msg['createAt'] ?? Timestamp.now(),
            });
            debugPrint("👉 Added: ${results.length}");
          }
        }
      }
    }

    // Sắp xếp theo thời gian gửi (mới nhất trước)
    results.sort((a, b) {
      final aTime = (a['createAt'] as Timestamp).toDate();
      final bTime = (b['createAt'] as Timestamp).toDate();
      return bTime.compareTo(aTime);
    });

    return results;
  }

  /// Widget tile hiển thị mỗi kết quả tin nhắn
  Widget _buildMessageTile({
    required String groupId,
    required String avatarUrl,
    required String groupName,
    required String messageText,
    required Timestamp createAt,
    required String highlight,
    required BuildContext context,
  }) {
    final dateTime = createAt.toDate();
    final formattedDate = DateFormat('HH:mm dd/MM').format(dateTime);

    final TextStyle normal = const TextStyle(fontSize: 16, color: Colors.black);
    final TextStyle highlightStyle = const TextStyle(
      backgroundColor: Color(0xFFFFE9A0),
      color: Colors.black,
      fontWeight: FontWeight.bold,
    );

    return ListTile(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GroupChatScreen(
              groupId: groupId,
              groupName: groupName,
            ),
          ),
        );
      },
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: Colors.green.shade200,
        backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
      ),
      title: _highlightText(groupName, highlight, normal, highlightStyle),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          _highlightText(
            messageText,
            highlight,
            const TextStyle(fontStyle: FontStyle.italic, color: Colors.black87),
            highlightStyle,
          ),
          const SizedBox(height: 2),
          Text(
            formattedDate,
            style: const TextStyle(
              color: Color(0xFF48623F),
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  /// Tô màu đoạn khớp từ khóa
  Widget _highlightText(String text, String query, TextStyle normal, TextStyle highlight) {
    if (query.isEmpty || !text.toLowerCase().contains(query.toLowerCase())) {
      return Text(text, style: normal);
    }

    final startIndex = text.toLowerCase().indexOf(query.toLowerCase());
    final endIndex = startIndex + query.length;

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(text: text.substring(0, startIndex), style: normal),
          TextSpan(text: text.substring(startIndex, endIndex), style: highlight),
          TextSpan(text: text.substring(endIndex), style: normal),
        ],
      ),
    );
  }
}
