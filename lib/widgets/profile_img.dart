import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:http/http.dart' as http; // <- thêm package này để upload Cloudinary

class ProfileImage extends StatefulWidget {
  final Size size;
  final String docId;

  const ProfileImage({super.key, required this.size, required this.docId});

  @override
  _ProfileImageState createState() => _ProfileImageState();
}

class _ProfileImageState extends State<ProfileImage> {
  String? avatarUrl;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchAvatar();
  }

  Future<void> _fetchAvatar() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.docId)
          .get();
      setState(() {
        avatarUrl = doc.data()?['avatar'] ?? 'assets/default_avatar.png';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch avatar: $e')),
      );
    }
  }

  Future<String?> _uploadToCloudinary(XFile file) async {
    const cloudName = 'dibmnb2rp';
    const uploadPreset = 'avatar_upload_preset';
    final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
        contentType: MediaType('image', 'jpeg'),
      ));

    try {
      // Gửi request và nhận phản hồi
      final response = await request.send();

      if (response.statusCode == 200) {
        final responseBody = await http.Response.fromStream(response);
        final data = jsonDecode(responseBody.body);
        return data['secure_url']; // Trả về URL của ảnh đã upload
      } else {
        print('Upload failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error uploading to Cloudinary: $e');
      return null;
    }
  }

  Future<void> _updateAvatar() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final newAvatarUrl = await _uploadToCloudinary(pickedFile);

        if (newAvatarUrl != null) {
          // Update Firestore
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.docId)
              .update({'avatar': newAvatarUrl});

          setState(() {
            avatarUrl = newAvatarUrl;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload avatar')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update avatar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Cover background
        Container(
          width: widget.size.width,
          height: 200,
          color: Colors.transparent,
          padding: const EdgeInsets.only(bottom: 150 / 2.2),
          child: Container(
            width: widget.size.width,
            height: 150,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.elliptical(10, 10),
                bottomRight: Radius.elliptical(10, 10),
              ),
              image: DecorationImage(
                image:  avatarUrl != null
                    ? NetworkImage(avatarUrl!)
                    : const AssetImage('assets/default_avatar.png') as ImageProvider,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),

        // Avatar
        Positioned(
          top: 100,
          left: widget.size.width / 2 - 50,
          child: GestureDetector(
            onTap: _updateAvatar,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.white, width: 3),
                shape: BoxShape.circle,
              ),
              child: CircleAvatar(
                backgroundColor: Colors.transparent,
                backgroundImage: avatarUrl != null
                    ? NetworkImage(avatarUrl!)
                    : const AssetImage('assets/default_avatar.png') as ImageProvider,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
