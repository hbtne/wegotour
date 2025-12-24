import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:stour/screens/profile.dart';

import '../assets/icons/chat_svg.dart';
import 'friend_message.dart';
import 'list_friend_screen.dart';

class SearchFriendScreen extends StatefulWidget {
  final List<FriendItem> friends;

  const SearchFriendScreen({super.key, required this.friends});

  @override
  State<SearchFriendScreen> createState() => _SearchFriendScreenState();
}

class _SearchFriendScreenState extends State<SearchFriendScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<FriendItem> filteredFriends = [];

  @override
  void initState() {
    super.initState();
    filteredFriends = widget.friends;
  }

  void _onSearchChanged(String value) {
    final keyword = value.toLowerCase();

    setState(() {
      filteredFriends = widget.friends.where((friend) {
        return friend.username.toLowerCase().contains(keyword);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = const Color(0xFF4A5C3B);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: primary),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        centerTitle: true,
        title: Text(
          'TÌM BẠN',
          style: TextStyle(
            color: primary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: "Nhập tên người dùng...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          Expanded(
            child: filteredFriends.isEmpty
                ? const Center(child: Text("Không tìm thấy bạn bè."))
                : ListView.builder(
              itemCount: filteredFriends.length,
              itemBuilder: (context, index) {
                final friend = filteredFriends[index];

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(friend.avatar),
                  ),
                  title: Text(friend.username),
                  trailing: IconButton(
                    icon: SvgPicture.string(chatSVG, width: 25, height: 25,),
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
                    Navigator.push(context, MaterialPageRoute(builder: (_)=> Profile(profileId: friend.friendId,)));
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
