import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController msgCtrl = TextEditingController();
  final ScrollController scrollCtrl = ScrollController();
  final user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    const Color primary = Color(0xFF4A5C3B);
    const Color greenBubble = Color(0xFF8E9F87);
    const Color yellowBubble = Color(0xFFFFE7A6);

    _setReadMessage();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: primary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  Text(
                    "NHÓM ${widget.groupName.toUpperCase()}",
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      color: primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // --- MESSAGE LIST ---
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('groups')
                    .doc(widget.groupId)
                    .collection('messages')
                    .orderBy('createdAt', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final messages = snapshot.data!.docs;

                  return ListView.builder(
                    controller: scrollCtrl,
                    padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index].data() as Map<String, dynamic>;
                      final isSelf = msg['senderId'] == user?.uid;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: isSelf
                            ? _messageSelf(msg['text'] ?? '')
                            : _messageRow(
                          name: msg['senderName'] ?? '',
                          msg: msg['text'] ?? '',
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // --- INPUT BAR ---
            Container(
              height: 65,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: yellowBubble,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Row(
                children: [
                  const Icon(Icons.attach_file, color: primary),
                  const SizedBox(width: 14),
                  const Icon(Icons.mic, color: primary),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextField(
                      controller: msgCtrl,
                      decoration: const InputDecoration(
                        hintText: "Nhập tin nhắn...",
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: primary),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- OTHER USERS MESSAGE ---
  Widget _messageRow({required String name, required String msg}) {
    const Color greenBubble = Color(0xFF8E9F87);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFF97A989),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: greenBubble,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(msg, style: const TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  // --- SELF MESSAGE ---
  Widget _messageSelf(String msg) {
    const Color yellowBubble = Color(0xFFFFE7A6);

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: yellowBubble,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(msg, style: const TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Future<void> _setReadMessage() async {
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .update({'unread': false});
  }

  // --- GỬI TIN NHẮN ---
  Future<void> _sendMessage() async {
    final text = msgCtrl.text.trim();
    if (text.isEmpty || user == null) return;

    final msgRef = FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('messages');

    await msgRef.add({
      'senderId': user!.uid,
      'senderName': user!.displayName ?? 'Ẩn danh',
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .update({
      'lastMessage': text,
      'lastTime': FieldValue.serverTimestamp(),
      'unread': true,
    });

      msgCtrl.clear();

      // Cuộn xuống cuối
      Future.delayed(const Duration(milliseconds: 200), () {
        if (scrollCtrl.hasClients) {
          scrollCtrl.jumpTo(scrollCtrl.position.maxScrollExtent);
        }
      });
  }
}
