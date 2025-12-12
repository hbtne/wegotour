import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:stour/screens/profile_post.dart';
import 'package:stour/screens/saved_tour.dart';
import 'package:stour/assets/icons/bio_svg.dart' as BioIcon;
import 'package:stour/assets/icons/locate_svg.dart' as LocateIcon;
import 'package:stour/widgets/profile_img.dart';
import 'package:stour/screens/addPost_screen.dart';

import '../util/places.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  _ProfileState createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final int _selectedEvent = 0;
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

  final List<Widget> _pages = [const PostScreen()];

  Future<void> _logout(BuildContext context) async {
    try {
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
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final data = await getProfileData(user.uid);
        setState(() {
          _profileData = data;
          _isLoading = false;
        });
      }
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
            .doc(user.uid)
            .collection('badges')
            .get();

        print('📛 Found ${badgesSnap.docs.length} badges');

        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
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
        child: SingleChildScrollView(
          child: Column(
            children: [
              ProfileImage(
                  size: size,
                  docId: FirebaseAuth.instance.currentUser?.uid ?? ""),
              profileInfo(),
              profileActivity(),
              // ✅ Thêm phần hiển thị badges
              if (!_isLoading && _profileData != null) _buildBadgesSection(),
              if (!_isLoading && _profileData != null) profileEvents(size),
              SizedBox(
                height: 5530,
                child: _pages[_selectedEvent],
              ),
            ],
          ),
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
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxHeight: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Chọn huy hiệu hiển thị',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D4D0A),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: _badges.length,
                  itemBuilder: (ctx, i) {
                    final badge = _badges[i];
                    final icon = badge['icon'] ?? '';
                    final name = badge['name'] ?? 'Badge';
                    final badgeId = badge['id'];
                    final isSelected = badgeId == _selectedBadgeId;
                    final earnedAt = badge['earnedAt'];

                    return GestureDetector(
                      onTap: () async {
                        await _selectBadge(badgeId);
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.amber.shade50
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Colors.amber
                                : Colors.grey.shade300,
                            width: isSelected ? 3 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isSelected)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 4),
                                child: Icon(
                                  Icons.check_circle,
                                  color: Colors.amber,
                                  size: 20,
                                ),
                              ),
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
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
                                          size: 28,
                                          color: Colors.amber,
                                        ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.emoji_events,
                                      size: 28,
                                      color: Colors.amber,
                                    ),
                            ),
                            const SizedBox(height: 6),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                name,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: const Color(0xFF2D4D0A),
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
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Đóng',
                  style: TextStyle(color: Color(0xFF2D4D0A)),
                ),
              ),
            ],
          ),
        ),
      ),
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
            _buildEventButton("Đánh giá", 1,
                (_profileData!['reviews'] as List?)?.length.toString() ?? "0"),
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

  Widget profileInfo() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_profileData == null) {
      return const Center(child: Text("Failed to load profile"));
    }
    return Column(
      children: [
        Text(
          _profileData!['username'] ?? "Unknown",
          style: const TextStyle(
            color: Color.fromARGB(255, 35, 52, 10),
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
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
    };
  } catch (e) {
    throw Exception('Error fetching profile data: $e');
  }
}
