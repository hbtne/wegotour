import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/cloudinary_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../util/places.dart';
import 'package:stour/assets/icons/send_svg.dart' as sendIcon;
import 'package:multi_select_flutter/multi_select_flutter.dart';


class AddPostScreen extends StatefulWidget {
  final Map<String, dynamic>? existingPost;
  final String? postId;
  final String? groupId;

  const AddPostScreen({super.key, this.existingPost, this.postId, this.groupId});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final TextEditingController _postController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<File> _newImages = [];
  List<String> _existingImageUrls = [];
  List<Map<String, dynamic>> allPlaces = [];
  List<Map<String, dynamic>> selectedPlaces = [];
  bool _isPosting = false;
  Map<String, dynamic>? userData;
  final User? user = FirebaseAuth.instance.currentUser;
  List<String> selectedPlaceIds = [];


  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchPlaces();

    if (widget.existingPost != null) {
      _postController.text = widget.existingPost!['content'] ?? '';
      _locationController.text = widget.existingPost!['location'] ?? currentLocationDetail[1];
      _existingImageUrls = List<String>.from(widget.existingPost!['imageUrls'] ?? []);

      selectedPlaces = List<Map<String, dynamic>>.from(widget.existingPost!['places'] ?? []);
    }
    else {
      _locationController.text = currentLocationDetail[1]; // mặc định địa điểm
    }

  }
  Future<void> _fetchPlaces() async {
    final foodSnapshot = await _firestore.collection('food').get();
    final placeSnapshot = await _firestore.collection('stourplace1').get();

    final places = [
      ...foodSnapshot.docs.map((doc) => {
        'id': doc.id,
        'name': doc['name'],
        'type': 'food',
      }),
      ...placeSnapshot.docs.map((doc) => {
        'id': doc.id,
        'name': doc['name'],
        'type': 'stourplace1',
      }),
    ];
    setState(() {
      allPlaces = places;
    });
  }
  Future<void> _loadUserData() async {
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (doc.exists) {
        setState(() {
          userData = doc.data();
        });
      }
    }
  }
  void _togglePlaceSelection(Map<String, dynamic> place) {
    setState(() {
      if (selectedPlaces.any((p) => p['id'] == place['id'] && p['type'] == place['type'])) {
        selectedPlaces.removeWhere((p) => p['id'] == place['id'] && p['type'] == place['type']);
      } else {
        selectedPlaces.add(place);
      }

      _locationController.text = selectedPlaces.map((p) => p['name']).join(', ');
    });
  }

  Future<void> _pickImages() async {
    final pickedFiles = await ImagePicker().pickMultiImage();
    if (pickedFiles != null && pickedFiles.isNotEmpty) {
      setState(() {
        _newImages.addAll(pickedFiles.map((file) => File(file.path)));
      });
    }
  }

  void _removeImage(int index, {bool isExisting = false}) {
    setState(() {
      if (isExisting) {
        _existingImageUrls.removeAt(index);
      } else {
        _newImages.removeAt(index);
      }
    });
  }

  Future<void> _submitPost() async {
    if (_postController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập nội dung bài viết')),
      );
      return;
    }

    setState(() {
      _isPosting = true;
    });

    try {
      final newImageUrls = await _cloudinaryService.uploadImages(
        _newImages.map((file) => file.path).toList(),
      );

      final allImageUrls = [..._existingImageUrls, ...newImageUrls];

      if (widget.existingPost != null && widget.postId != null) {
        await FirebaseFirestore.instance.collection('posts').doc(widget.postId).update({
          'groupid': widget.groupId,
          'content': _postController.text,
          'location': _locationController.text,
          'imageUrls': allImageUrls,
          'updatedAt': Timestamp.now(),
          'places': selectedPlaces.map((p) => p['id']).toList(), // Chỉ lưu ID
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật bài viết thành công')),
        );
      } else {
        final newPostRef = _firestore.collection('posts').doc(); // auto ID
        final postId = newPostRef.id;
        await newPostRef.set({
          'userId': user?.uid,
          'content': _postController.text,
          'imageUrls': allImageUrls,
          'groupId': widget.groupId,
          'places': selectedPlaces.map((p) => p['id']).toList(),
          'timestamp': FieldValue.serverTimestamp(),
          'createdAt': Timestamp.now(),
          'authorId': user?.uid,
          'location': _locationController.text,
          'likes': 0,
          'likedBy': [],
          'comments': 0,
          'shares': 0,
          'ccomments': [],
        });

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .update({
          'posts': FieldValue.arrayUnion([postId])
        });

        if (widget.groupId != null)
        {
          await FirebaseFirestore.instance.collection('groups').doc(
              widget.groupId).update({
            'posts': FieldValue.arrayUnion([postId])
          });
        }

        for (final place in selectedPlaces) {
          final placeRef = _firestore.collection(place['type']).doc(place['id']);
          await placeRef.update({
            'postIds': FieldValue.arrayUnion([postId])
          });
        }
      }

      Navigator.pop(context);
    } catch (e) {
      print("Lỗi khi đăng bài: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đã có lỗi xảy ra. Vui lòng thử lại")),
      );
    }

    setState(() {
      _isPosting = false;
    });
  }



  @override
  void dispose() {
    _postController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.existingPost != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditMode ? 'CHỈNH SỬA BÀI VIẾT' : 'THÊM BÀI VIẾT',
          style: const TextStyle(
            color: Color(0xFF3B6332),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isPosting ? null : _submitPost,
            child: _isPosting
                ? const CircularProgressIndicator()
                : SvgPicture.string(sendIcon.sendSVG, height: 40, width: 40),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: userData?['avatar'] != null
                      ? NetworkImage(userData!['avatar'])
                      : const AssetImage('assets/default_avatar.png') as ImageProvider,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userData?['username'] ?? "Người dùng",
                      style: const TextStyle(
                        color: Color(0xFF3B6332),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      isEditMode ? 'Chỉnh sửa' : "Bây giờ",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _postController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Chia sẻ cảm nghĩ của bạn...',
                border: InputBorder.none,
              ),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            const Text('Vị trí', style: TextStyle(color: Color(0xFF3B6332), fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.location_on, color: Color(0xFFFFD166)),
              ),
            ),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Chọn địa điểm:',style: TextStyle(color: Color(0xFF3B6332), fontWeight: FontWeight.bold)),
            ),
            MultiSelectDialogField<String>(
              items: allPlaces
                  .map((place) => MultiSelectItem<String>(place['id'], place['name']))
                  .toList(),
              title: const Text("Chọn địa điểm"),
              selectedColor: Colors.green,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.grey,
                ),
              ),
              buttonIcon: const Icon(
                Icons.place,
                color: Color(0xFF3B6332),
              ),
              buttonText: const Text(
                "Chọn địa điểm",
                style: TextStyle(
                  color: Color(0xFF3B6332),
                  fontSize: 16,
                ),
              ),
              initialValue: selectedPlaceIds,
              onConfirm: (List<String> selectedIds) {
                setState(() {
                  selectedPlaceIds = selectedIds;

                  // Gợi ý để hiển thị chip
                  selectedPlaces = allPlaces
                      .where((place) => selectedIds.contains(place['id']))
                      .toList();

                  _locationController.text =
                      selectedPlaces.map((e) => e['name']).join(', ');
                });
              },
              chipDisplay: MultiSelectChipDisplay(
                onTap: (item) {
                  setState(() {
                    selectedPlaceIds.remove(item);
                    selectedPlaces =
                        allPlaces.where((place) => selectedPlaceIds.contains(place['id'])).toList();
                    _locationController.text =
                        selectedPlaces.map((e) => e['name']).join(', ');
                  });
                },
              ),
            ),


            // const SizedBox(height: 10),
            //
            // Container(
            //   padding: const EdgeInsets.all(10),
            //   decoration: BoxDecoration(
            //     border: Border.all(color: Colors.grey),
            //     borderRadius: BorderRadius.circular(10),
            //   ),
            //   child: Row(
            //     children: [
            //       const Icon(Icons.location_on, color: Color(0xFFFFD166)),
            //       const SizedBox(width: 8),
            //       Expanded(
            //         child: Wrap(
            //           spacing: 6.0,
            //           children: selectedPlaces.map((place) {
            //             return Chip(
            //               label: Text(place['name']),
            //               onDeleted: () => _togglePlaceSelection(place),
            //             );
            //           }).toList(),
            //         ),
            //       ),
            //     ],
            //   ),
            // ),

            // const SizedBox(height: 20),
            // if (selectedPlaces.isNotEmpty)
            //   Wrap(
            //     spacing: 6.0,
            //     children: selectedPlaces.map((place) {
            //       return Chip(
            //         label: Text(place['name']),
            //         onDeleted: () => _togglePlaceSelection(place),
            //       );
            //     }).toList(),
            //   ),

          // const SizedBox(height: 8),
          //   TextField(
          //     controller: _locationController,
          //     decoration: InputDecoration(
          //       border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          //       prefixIcon: const Icon(Icons.location_on, color: Color(0xFFFFD166)),
          //     ),
          //   ),
            const SizedBox(height: 20),
            const Text('File đính kèm', style: TextStyle(color: Color(0xFF3B6332), fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            // Hiển thị ảnh đã có (url)
            if (_existingImageUrls.isNotEmpty)
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _existingImageUrls.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            image: DecorationImage(
                              image: NetworkImage(_existingImageUrls[index]),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 5,
                          right: 5,
                          child: GestureDetector(
                            onTap: () => _removeImage(index, isExisting: true),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

            // Hiển thị ảnh mới chọn (File)
            if (_newImages.isNotEmpty)
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _newImages.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            image: DecorationImage(
                              image: FileImage(_newImages[index]),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 5,
                          right: 5,
                          child: GestureDetector(
                            onTap: () => _removeImage(index, isExisting: false),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

            GestureDetector(
              onTap: _pickImages,
              child: Container(
                height: 150,
                width: double.infinity,
                margin: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate, size: 30, color: Color(0xFF3B6332)),
                      SizedBox(height: 10),
                      Text('Thêm ảnh'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
