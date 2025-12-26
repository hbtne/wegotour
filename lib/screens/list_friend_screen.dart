import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:stour/assets/icons/chat_svg.dart';
import 'package:stour/assets/icons/find_group_svg.dart';
import 'package:stour/screens/friend_message.dart';
import 'package:stour/screens/profile.dart';

import 'find_friend.dart';

class FriendListScreen extends StatefulWidget {
  final String currentUserId;

  const FriendListScreen({super.key, required this.currentUserId});

  @override
  State<FriendListScreen> createState() => _FriendListScreenState();
}

class _FriendListScreenState extends State<FriendListScreen> {
  List<FriendItem> friends = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadFriends();
  }

  Future<void> loadFriends() async {
    try {
      final result = await fetchFriends(widget.currentUserId);
      if (!mounted) return;
      setState(() {
        friends = result;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Load friends error: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = const Color(0xFF4A5C3B);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primary),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'BẠN BÈ',
          style: TextStyle(
            color: primary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: SvgPicture.string(findGroupSVG, width: 30, height: 30),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SearchFriendScreen(friends: friends),
                ),
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : friends.isEmpty
          ? const Center(child: Text("Tệ quá! Không có ai ở đây cả :("))
          : ListView.builder(
        itemCount: friends.length,
        itemBuilder: (context, index) {
          final friend = friends[index];

          return ListTile(
            leading: CircleAvatar(
              backgroundImage: friend.avatar.isNotEmpty
                  ? NetworkImage(friend.avatar)
                  : const AssetImage(
                  'assets/default_avatar.png')
              as ImageProvider,
            ),
            title: Text(friend.username),
            trailing: IconButton(
              icon:
              SvgPicture.string(chatSVG, width: 25, height: 25),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PersonalChatScreen(
                      friendId: friend.friendId,
                      friendName: friend.username,
                    ),
                  ),
                );
              },
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      Profile(profileId: friend.friendId),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<List<FriendItem>> fetchFriends(String currentUserId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();

      final List messages = userDoc.data()?['messages'] ?? [];

      final futures = messages.map((item) async {
        final String friendId = item['friendId'];
        final String messageId = item['id'];

        final friendDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(friendId)
            .get();

        if (!friendDoc.exists) return null;

        final data = friendDoc.data()!;
        return FriendItem(
          friendId: friendId,
          username: data['username'] ?? 'Không tên',
          avatar: data['avatar'] ?? '',
          messageId: messageId,
        );
      });

      final results = await Future.wait(futures);
      return results.whereType<FriendItem>().toList();
    } catch (e) {
      debugPrint('Fetch friends error: $e');
      return [];
    }
  }
}

class FriendItem {
  final String friendId;
  final String username;
  final String avatar;
  final String messageId;

  FriendItem({
    required this.friendId,
    required this.username,
    required this.avatar,
    required this.messageId,
  });
}
