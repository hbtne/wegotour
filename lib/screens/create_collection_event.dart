import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import '../services/cloudinary_service.dart';

class CreateCollectionEvent extends StatefulWidget {
  const CreateCollectionEvent({super.key});

  @override
  State<CreateCollectionEvent> createState() => _CreateCollectionEventState();
}

class _CreateCollectionEventState extends State<CreateCollectionEvent> {
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _keywordsCtrl = TextEditingController();

  final CloudinaryService _cloudinaryService = CloudinaryService();

  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(days: 7));

  File? _badgeImage;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _keywordsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBadgeImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (picked != null) {
      setState(() {
        _badgeImage = File(picked.path);
      });
    }
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('Bạn cần đăng nhập để tạo event');
      return;
    }

    if (_badgeImage == null) {
      _showError('Vui lòng chọn hình ảnh huy hiệu');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final title = _titleCtrl.text.trim();
      final badgeId =
          'badge_${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';

      final keywords = _keywordsCtrl.text
          .split(',')
          .map((k) => k.trim().toLowerCase())
          .where((k) => k.isNotEmpty)
          .toList();

      if (keywords.isEmpty) {
        _showError('Vui lòng nhập ít nhất 1 từ khóa');
        setState(() => _isLoading = false);
        return;
      }

      final uploadedUrls = await _cloudinaryService.uploadImages(
        [_badgeImage!.path],
      );
      final badgeIconUrl = uploadedUrls.first;

      final event = {
        'title': title,
        'description': _descCtrl.text.trim(),
        'keywords': keywords,
        'category': 'collection',
        'startAt': Timestamp.fromDate(_start),
        'endAt': Timestamp.fromDate(_end),
        'createdBy': user.uid,
        'createdAt': Timestamp.now(),
        'badge': {
          'id': badgeId,
          'name': 'Huy hiệu $title',
          'icon': badgeIconUrl,
          'description': 'Huy hiệu sự kiện $title',
        },
        'processed': false,
      };

      await FirebaseFirestore.instance.collection('collect_events').add(event);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Tạo sự kiện "$title" thành công!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError('Lỗi khi tạo sự kiện: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TẠO SỰ KIỆN', style: TextStyle(color: Color.fromRGBO(59, 99, 50, 1), fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Tiêu đề sự kiện'),
                    _input(_titleCtrl, 'Nhập tiêu đề'),

                    _label('Mô tả sự kiện'),
                    _input(_descCtrl, 'Nhập mô tả'),

                    _label('Từ khóa'),
                    _input(
                      _keywordsCtrl,
                      'Mỗi từ cách nhau bằng dấu phẩy',
                      maxLines: 2,
                    ),

                    const SizedBox(height: 20),

                    // ================= TIME =================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _timeBox(
                          'Bắt đầu',
                          _start,
                          () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _start,
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2100),
                            );
                            if (d != null) setState(() => _start = d);
                          },
                        ),
                        _timeBox(
                          'Kết thúc',
                          _end,
                          () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _end,
                              firstDate: _start,
                              lastDate: DateTime(2100),
                            );
                            if (d != null) setState(() => _end = d);
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ================= BADGE IMAGE =================
                    _label('Hình ảnh huy hiệu'),

                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE8B6),
                              borderRadius: BorderRadius.circular(12),
                              image: _badgeImage != null
                                  ? DecorationImage(
                                      image: FileImage(_badgeImage!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                              border: Border.all(color: Colors.green),
                            ),
                            child: _badgeImage == null
                                ? const Center(
                                    child: Text(
                                      'Chưa chọn ảnh',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: _pickBadgeImage,
                          child: Container(
                            height: 120,
                            width: 60,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD166),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.image,
                              size: 30,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // ================= BUTTONS =================
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Hủy'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF3B6332),
                              side: const BorderSide(color: Color(0xFF3B6332)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _create,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B6332),
                            ),
                            child: const Text('Tạo sự kiện', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),

                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // ================= UI HELPERS =================
  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF3B6332),
        ),
      ),
    );
  }

  Widget _input(TextEditingController ctrl, String hint, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        validator: (v) =>
            v == null || v.trim().isEmpty ? 'Không được để trống' : null,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: const Color(0xFFFFE8B6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _timeBox(String label, DateTime time, VoidCallback onTap) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFF3B6332))),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE8B6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${time.day}/${time.month}/${time.year}',
                style: const TextStyle(fontWeight: FontWeight.w300),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
