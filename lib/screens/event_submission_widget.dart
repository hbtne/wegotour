import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:stour/services/vision_api_service.dart';
import 'package:stour/services/cloudinary_service.dart'; 
import 'package:stour/assets/icons/send_svg.dart' as sendIcon;
import 'package:flutter_svg/flutter_svg.dart';

class EventSubmissionScreen extends StatefulWidget {
  final String eventId;
  final List<String> keywords;

  const EventSubmissionScreen({
    super.key,
    required this.eventId,
    required this.keywords,
  });

  @override
  State<EventSubmissionScreen> createState() => _EventSubmissionScreenState();
}

class _EventSubmissionScreenState extends State<EventSubmissionScreen> {
  final _captionController = TextEditingController();
  final CloudinaryService _cloudinaryService =
      CloudinaryService(); // ✅ Khởi tạo

  File? _selectedImage;
  bool _isLoading = false;
  bool _isValidating = false;
  Map<String, dynamic>? _validationResult;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _validationResult = null;
        });

        // Auto validate
        await _validateImage();
      }
    } catch (e) {
      _showError('Lỗi khi chọn ảnh: $e');
    }
  }

  Future<void> _validateImage() async {
    if (_selectedImage == null) return;

    setState(() => _isValidating = true);

    try {
      final result = await VisionApiService.validateImage(
        imageFile: _selectedImage!,
        requiredKeywords: widget.keywords,
      );

      setState(() {
        _validationResult = result;
        _isValidating = false;
      });

      if (result['isValid'] == true) {
        _showSuccess(result['message']);
      } else {
        _showError(result['message']);
      }
    } catch (e) {
      setState(() => _isValidating = false);
      print('Vision API Error: $e');

      _showError('Không thể xác minh ảnh. Vui lòng thử lại sau.');
      setState(() {
        _validationResult = {
          'isValid': false,
          'message': 'Lỗi xác minh ảnh',
        };
      });
    }
  }

  Future<void> _submitPost() async {
    if (_selectedImage == null) {
      _showError('Vui lòng chọn ảnh');
      return;
    }

    if (_validationResult == null || _validationResult!['isValid'] != true) {
      _showError('Ảnh chưa được validate hoặc không hợp lệ');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('Bạn cần đăng nhập');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ✅ 1. UPLOAD ẢNH LÊN CLOUDINARY (thay vì Firebase Storage)
      print('📤 Uploading to Cloudinary...');

      final imageUrls =
          await _cloudinaryService.uploadImages([_selectedImage!.path]);

      if (imageUrls.isEmpty) {
        throw Exception('Upload ảnh thất bại');
      }

      final imageUrl = imageUrls[0];
      print('✅ Upload success: $imageUrl');

      // 2. Lấy thông tin user
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data();
      final userName = userData?['name'] ??
          userData?['username'] ??
          user.displayName ??
          'Unknown';
      final userAvatar = userData?['avatar'] ?? user.photoURL ?? '';

      // 3. Tạo submission
      final submissionData = {
        'eventId': widget.eventId,
        'userId': user.uid,
        'userName': userName,
        'userAvatar': userAvatar,
        'imageUrl': imageUrl, // 
        'caption': _captionController.text.trim(),
        'detectedLabels': _validationResult!['detectedLabels'] ?? [],
        'matchedKeywords': _validationResult!['matchedKeywords'] ?? [],
        'isValid': _validationResult!['isValid'] ?? false,
        'requiresReview': _validationResult!['requiresReview'] ?? false,
        'likes': 0,
        'comments': 0,
        'shares': 0,
        'score': 0,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // 4. Lưu submission
      final submissionRef = await FirebaseFirestore.instance
          .collection('collect_events')
          .doc(widget.eventId)
          .collection('submissions')
          .add(submissionData);

      print('✅ Submission created: ${submissionRef.id}');

      // 5. Cập nhật leaderboard
      await _updateLeaderboard(
          user.uid, userName, userAvatar, submissionRef.id);

      // 6. Thành công
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Đăng bài thành công!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } on FirebaseException catch (e) {
      print('❌ Firestore error: ${e.code} - ${e.message}');
      _showError('Lỗi Firestore: ${e.message}');
    } catch (e) {
      print('❌ Upload error: $e');
      _showError('Lỗi khi đăng bài: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateLeaderboard(String userId, String userName,
      String userAvatar, String submissionId) async {
    final leaderboardRef = FirebaseFirestore.instance
        .collection('collect_events')
        .doc(widget.eventId)
        .collection('leaderboard')
        .doc(userId);

    final doc = await leaderboardRef.get();

    if (doc.exists) {
      await leaderboardRef.update({
        'submissionCount': FieldValue.increment(1),
        'submissionIds': FieldValue.arrayUnion([submissionId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await leaderboardRef.set({
        'userName': userName,
        'userAvatar': userAvatar,
        'totalScore': 0,
        'submissionCount': 1,
        'submissionIds': [submissionId],
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng bài tham gia',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF3B6332))),
        actions: [
          if (_selectedImage != null && _validationResult?['isValid'] == true)
            TextButton(
              onPressed: _isLoading ? null : _submitPost,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  :  SvgPicture.string(sendIcon.sendSVG, height: 40, width: 40),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Keywords requirement
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Yêu cầu ảnh',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3B6332))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Ảnh phải chứa ít nhất 1 trong các từ khóa:'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.keywords
                          .map((kw) => Chip(
                                label: Text(kw),
                                backgroundColor: Colors.white,
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Image preview
            if (_selectedImage != null) ...[
              Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _selectedImage!,
                      height: 300,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      style:
                          IconButton.styleFrom(backgroundColor: Colors.black54),
                      onPressed: () => setState(() {
                        _selectedImage = null;
                        _validationResult = null;
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Validation status
              if (_isValidating)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 16),
                        Text('Đợi Wee kiểm tra ảnh 1 xíu nha...'),
                      ],
                    ),
                  ),
                ),

              if (!_isValidating && _validationResult != null)
                Card(
                  color: _validationResult!['isValid'] == true
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _validationResult!['isValid'] == true
                                  ? Icons.check_circle
                                  : Icons.error,
                              color: _validationResult!['isValid'] == true
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _validationResult!['message'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        if (_validationResult!['matchedKeywords'] != null &&
                            (_validationResult!['matchedKeywords'] as List)
                                .isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text('Từ khóa tìm thấy:',
                              style: TextStyle(fontSize: 12)),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            children: (_validationResult!['matchedKeywords']
                                    as List)
                                .map((kw) => Chip(
                                      label: Text(kw,
                                          style: const TextStyle(fontSize: 12)),
                                      backgroundColor: Colors.green.shade100,
                                      padding: EdgeInsets.zero,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ))
                                .toList(),
                          ),
                        ],
                        if (_validationResult!['detectedLabels'] != null &&
                            (_validationResult!['detectedLabels'] as List)
                                .isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text('Wee thấy ảnh của bạn có:',
                              style:
                                  TextStyle(fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(
                            (_validationResult!['detectedLabels'] as List)
                                .take(5)
                                .join(', '),
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ] else ...[
              // Pick image buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text(
                        'Chụp ảnh',
                        style: TextStyle(color: Color(0xFF3B6332)),
                      ),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          iconColor: const Color(0xFF3B6332),
                          backgroundColor:
                              const Color.fromARGB(215, 255, 209, 102)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Thư viện',
                          style: TextStyle(color: Color(0xFF3B6332))),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          iconColor: const Color(0xFF3B6332),
                          backgroundColor:
                              const Color.fromARGB(215, 255, 209, 102)),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // Caption
            TextField(
              controller: _captionController,
              cursorColor: const Color(0xFF3B6332),
              focusNode: FocusNode(),
              decoration: InputDecoration(
                labelText: 'Mô tả bài đăng (tùy chọn)',
                hintText: 'Viết gì đó về ảnh của bạn...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3B6332))),
                prefixIcon: const Icon(
                  Icons.edit,
                  color: Color(0xFF3B6332),
                ),
                iconColor: const Color(0xFF3B6332),
                focusColor: const Color(0xFF3B6332),
              ),
              maxLines: 3,
              maxLength: 500,
            ),
          ],
        ),
      ),
    );
  }
}
