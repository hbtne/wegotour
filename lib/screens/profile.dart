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

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color.fromARGB(255, 35, 52, 10)),
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
              ProfileImage(size: size, docId: FirebaseAuth.instance.currentUser?.uid ?? ""),
              profileInfo(),
              profileActivity(),
              if (!_isLoading && _profileData != null)
                profileEvents(size),
              SizedBox(
                height: 5530, // Constrain the height of the PostScreen
                child: _pages[_selectedEvent],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget profileEvents(Size size) {
    return Column(
      children: [
        const Divider(height: 1, thickness: 1),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildEventButton("Bài viết", 0,(_profileData!['posts'] as List?)?.length.toString() ?? "0"),
            _buildEventButton("Đánh giá", 1, (_profileData!['reviews'] as List?)?.length.toString() ?? "0"),
            _buildEventButton("Lịch trình", 2, (_profileData!['saveTours'] as List?)?.length.toString() ?? "0"),

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
                _fetchProfile(); // Reload lại dữ liệu
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
          style: TextStyle(
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
              style: TextStyle(
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
    return const SizedBox(height: 16); // Placeholder or custom widget
  }
}
Future<Map<String, dynamic>> getProfileData(String docId) async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  try {
    // Fetch user data from Firestore
    final userDoc = await firestore.collection('users').doc(docId).get();
    if (!userDoc.exists) {
      throw Exception('User not found');
    }

    final username = userDoc.data()?['username'] ?? 'Unknown';



    // Combine Firestore data with location data
    return {
      'avatar': userDoc.data()?['avatar'] ?? 'default_avatar.png',
      'posts': userDoc.data()?['posts'] ?? [],
      'reviews': userDoc.data()?['reviews'] ?? [],
      'saveTours': userDoc.data()?['saveTours'] ?? [],
      'username': username,
      'location': currentLocationDetail[1],
    };
  } catch (e) {
    throw Exception('Error fetching profile data: $e');
  }
}