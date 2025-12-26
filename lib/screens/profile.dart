import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:stour/assets/icons/person_check_svg.dart';
import 'package:stour/screens/friend_message.dart';
import 'package:stour/screens/list_friend_screen.dart';

import 'package:stour/screens/profile_post.dart';
import 'package:stour/screens/saved_tour.dart';
import 'package:stour/assets/icons/bio_svg.dart' as BioIcon;
import 'package:stour/assets/icons/locate_svg.dart' as LocateIcon;
import 'package:stour/services/auth_service.dart';
import 'package:stour/widgets/profile_img.dart';
import 'package:stour/screens/addPost_screen.dart';

import '../util/places.dart';

class Profile extends StatefulWidget {
  final String profileId;
  const Profile({super.key, required this.profileId});

  @override
  _ProfileState createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  int _selectedEvent = 0;
  final int _currentIndex = 2;
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;
  List<Map<String, dynamic>> _badges = [];
  String? _selectedBadgeId;

  final List<IconData> icons = [
    Icons.timeline_outlined,
    Icons.home_outlined,
    Icons.person_outline,
  ];

  late String profileId;
  List<Widget> get _pages => [PostScreen(profileId: widget.profileId)];

  Future<void> _logout(BuildContext context) async {
    try {
      _profileData?.clear();
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacementNamed(context, '/signin');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _fetchBadges();
  }

  Future<void> _fetchProfile() async {
    try {
      final data = await getProfileData(widget.profileId);
      setState(() {
        _profileData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile: $e')),
      );
    }
  }

  Future<void> _fetchBadges() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print('🔍 Fetching badges for userId: ${user.uid}');

        final badgesSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.profileId)
            .collection('badges')
            .get();

        print('📛 Found ${badgesSnap.docs.length} badges');

        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.profileId)
            .get();

        setState(() {
          _badges = badgesSnap.docs.map((doc) {
            print('Badge: ${doc.id} - ${doc.data()}');
            return {'id': doc.id, ...doc.data()};
          }).toList();
          _selectedBadgeId = userDoc.data()?['selectedBadge'];
          print('✅ Total badges loaded: ${_badges.length}');
        });
      }
    } catch (e) {
      print('❌ Failed to load badges: $e');
    }
  }

  bool get _isFriend {
    final currentUid = AuthService.getCurrentUserId();
    if (currentUid == null) return false;

    return (_profileData?['friends'] as List?)?.contains(currentUid) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout,
                color: Color.fromARGB(255, 35, 52, 10)),
            onPressed: () {
              _logout(context);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ProfileImage(size: size, docId: widget.profileId),
            ),

            SliverToBoxAdapter(child: profileInfo()),
            SliverToBoxAdapter(child: profileActivity()),

            if (!_isLoading && _profileData != null)
              SliverToBoxAdapter(child: _buildBadgesSection()),

            if (!_isLoading && _profileData != null)
              SliverToBoxAdapter(child: profileEvents(size)),

            PostScreen(profileId: widget.profileId),
          ],
        ),
      ),
    );
  }

  // ✅ Widget hiển thị danh sách badges
  Widget _buildBadgesSection() {
    if (_badges.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Huy hiệu',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 35, 52, 10),
                ),
              ),
              TextButton(
                onPressed: _showBadgeSelectionDialog,
                child: const Text(
                  'Chọn huy hiệu',
                  style: TextStyle(color: Color(0xFF2D4D0A)),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _badges.length > 5 ? 5 : _badges.length,
            itemBuilder: (ctx, i) {
              final badge = _badges[i];
              final icon = badge['icon'] ?? '';
              final name = badge['name'] ?? 'Badge';
              final badgeId = badge['id'];
              final isSelected = badgeId == _selectedBadgeId;

              return GestureDetector(
                onTap: _showBadgeSelectionDialog,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[200],
                          border: Border.all(
                            color: isSelected
                                ? Colors.amber
                                : const Color(0xFF2D4D0A),
                            width: isSelected ? 3 : 2,
                          ),
                        ),
                        child: icon.isNotEmpty
                            ? ClipOval(
                                child: Image.network(
                                  icon,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.emoji_events,
                                    size: 32,
                                    color: Colors.amber,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.emoji_events,
                                size: 32,
                                color: Colors.amber,
                              ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 70,
                        child: Text(
                          name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: const Color.fromARGB(255, 35, 52, 10),
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        const Divider(height: 1, thickness: 1),
      ],
    );
  }

void _showBadgeSelectionDialog() {
  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: SizedBox(
          // 🔑 Chiều cao tối đa theo màn hình
          height: MediaQuery.of(context).size.height * 0.65,
          child: Column(
            children: [
              const SizedBox(height: 16),

              const Text(
                'Huy hiệu hiển thị',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D4D0A),
                ),
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),

              /// ✅ LISTVIEW – KHÔNG OVERFLOW
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _badges.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final badge = _badges[index];
                    final icon = badge['icon'] ?? '';
                    final name = badge['name'] ?? 'Badge';
                    final badgeId = badge['id'];
                    final isSelected = badgeId == _selectedBadgeId;

                    return ListTile(
                      onTap: () async {
                        await _selectBadge(badgeId);
                        Navigator.pop(context);
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected
                              ? Colors.amber
                              : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      tileColor: isSelected
                          ? Colors.amber.shade50
                          : Colors.grey.shade100,
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: icon.isNotEmpty
                            ? ClipOval(
                                child: Image.network(
                                  icon,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(
                                    Icons.emoji_events,
                                    color: Colors.amber,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.emoji_events,
                                color: Colors.amber,
                              ),
                      ),
                      title: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: const Color(0xFF2D4D0A),
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check_circle,
                              color: Colors.amber,
                            )
                          : null,
                    );
                  },
                ),
              ),

              const Divider(height: 1),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Đóng',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF2D4D0A),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}


  Future<void> _selectBadge(String badgeId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'selectedBadge': badgeId});

        setState(() {
          _selectedBadgeId = badgeId;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã chọn huy hiệu!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget profileEvents(Size size) {
    return Column(
      children: [
        const Divider(height: 1, thickness: 1),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildEventButton("Bài viết", 0,
                (_profileData!['posts'] as List?)?.length.toString() ?? "0"),
            TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FriendListScreen(currentUserId: widget.profileId == AuthService.getCurrentUserId() ? widget.profileId : '',))),
                child: _buildEventButton("Theo dõi", 1,
                  (_profileData!['messages'] as List?)?.length.toString() ?? "0")),
            _buildEventButton(
                "Lịch trình",
                2,
                (_profileData!['saveTours'] as List?)?.length.toString() ??
                    "0"),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(height: 1, thickness: 1),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton("Thêm bài viết", onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddPostScreen(),
                ),
              );
              if (result == true) {
                _fetchProfile();
              }
            }),
            _buildActionButton("Lịch trình đã lưu", onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SavedTour(),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(height: 1, thickness: 1),
      ],
    );
  }

  Widget _buildEventButton(String title, int index, String count) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color.fromARGB(255, 35, 52, 10),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            color: Color.fromARGB(255, 35, 52, 10),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(String text, {VoidCallback? onPressed}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFECB3),
        border: Border.all(color: const Color(0xFF2D4D0A)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          foregroundColor: const Color(0xFF2D4D0A),
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onPressed,
        child: Text(text),
      ),
    );
  }

  Future<void> _toggleFriend() async {
    final currentUid = AuthService.getCurrentUserId();
    final targetId = widget.profileId;

    if (currentUid == null || currentUid == targetId) return;

    final firestore = FirebaseFirestore.instance;
    final currentRef = firestore.collection('users').doc(currentUid);
    final targetRef = firestore.collection('users').doc(targetId);

    await firestore.runTransaction((tx) async {
      final currentSnap = await tx.get(currentRef);
      final targetSnap = await tx.get(targetRef);

      final currentFriends =
      List<String>.from(currentSnap['friends'] ?? []);
      final targetFriends =
      List<String>.from(targetSnap['friends'] ?? []);

      final isFriend = currentFriends.contains(targetId);

      if (isFriend) {
        currentFriends.remove(targetId);
        targetFriends.remove(currentUid);
      } else {
        currentFriends.add(targetId);
        targetFriends.add(currentUid);
      }

      tx.update(currentRef, {'friends': currentFriends});
      tx.update(targetRef, {'friends': targetFriends});
    });

    setState(() {
      _profileData!['friends'] =
      List<String>.from(_profileData!['friends'] ?? []);
    });
  }

  Widget profileInfo() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_profileData == null) {
      return const Center(child: Text("Failed to load profile"));
    }
    return Column(
      children: [
         Column(
           mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _profileData!['username'] ?? "Unknown",
                style: TextStyle(
                  color: Color.fromARGB(255, 35, 52, 10),
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              if (AuthService.getCurrentUserId() != widget.profileId) ...[
                _friendActivity()
              ]
            ]
         ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.string(BioIcon.bioSVG, height: 16, width: 16),
            const SizedBox(width: 4),
            const Text(
              "Ăn ngủ đi",
              style: TextStyle(
                color: Color.fromARGB(255, 35, 52, 10),
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 16),
            SvgPicture.string(LocateIcon.locateSVG, height: 16, width: 16),
            const SizedBox(width: 4),
            Text(
              _profileData!['location'] ?? "Unknown",
              style: const TextStyle(
                color: Color.fromARGB(255, 35, 52, 10),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget profileActivity() {
    return const SizedBox(height: 16);
  }

  Widget _friendActivity() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: _isFriend
              ? const Icon(Icons.person_remove, color: Colors.black87)
              : SvgPicture.string(personCheckSVG),
          onPressed: _toggleFriend,
        ),
        const SizedBox(width: 8),
        _buildActionButton(
          "Gửi tin nhắn",
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PersonalChatScreen(
                  friendId: widget.profileId,
                  friendName: _profileData!['username'],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

Future<Map<String, dynamic>> getProfileData(String docId) async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  try {
    final userDoc = await firestore.collection('users').doc(docId).get();
    if (!userDoc.exists) {
      throw Exception('User not found');
    }

    final username = userDoc.data()?['username'] ?? 'Unknown';

    return {
      'avatar': userDoc.data()?['avatar'] ?? 'default_avatar.png',
      'posts': userDoc.data()?['posts'] ?? [],
      'reviews': userDoc.data()?['reviews'] ?? [],
      'saveTours': userDoc.data()?['saveTours'] ?? [],
      'badges': userDoc.data()?['badges'] ?? [], // ✅ Thêm badges
      'username': username,
      'location': currentLocationDetail[1],
      'friends': userDoc.data()?['friends'] ?? [],
      'messages': userDoc.data()?['messages'] ??[]
    };
  } catch (e) {
    throw Exception('Error fetching profile data: $e');
  }
}
