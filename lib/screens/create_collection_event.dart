import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateCollectionEvent extends StatefulWidget {
  const CreateCollectionEvent({super.key});
  @override
  State<CreateCollectionEvent> createState() => _CreateCollectionEventState();
}

class _CreateCollectionEventState extends State<CreateCollectionEvent> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _badgeIconCtrl = TextEditingController();
  final _keywordsCtrl = TextEditingController(); // ← THÊM: Keywords cho Vision API
  
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(days: 7));
  bool _isLoading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _badgeIconCtrl.dispose();
    _keywordsCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('Bạn cần đăng nhập để tạo event');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final title = _titleCtrl.text.trim();
      final badgeId = 'badge_${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';
      
      // Parse keywords (phân tách bằng dấu phẩy)
      final keywordsText = _keywordsCtrl.text.trim();
      final keywords = keywordsText.isEmpty 
          ? <String>[]
          : keywordsText.split(',').map((k) => k.trim().toLowerCase()).where((k) => k.isNotEmpty).toList();

      if (keywords.isEmpty) {
        _showError('Vui lòng nhập ít nhất 1 từ khóa để validate ảnh');
        setState(() => _isLoading = false);
        return;
      }

      final event = {
        'title': title,
        'description': _descCtrl.text.trim(),
        'keywords': keywords, // ← THÊM: Keywords array
        'category': 'collection',
        'startAt': Timestamp.fromDate(_start),
        'endAt': Timestamp.fromDate(_end),
        'createdBy': user.uid,
        'createdAt': Timestamp.now(),
        'badge': {
          'id': badgeId,
          'name': 'Huy hiệu $title',
          'icon': _badgeIconCtrl.text.trim().isEmpty 
              ? 'https://via.placeholder.com/150' 
              : _badgeIconCtrl.text.trim(),
          'description': 'Huy hiệu sự kiện $title',
        },
        'processed': false,
      };

      await FirebaseFirestore.instance.collection('collect_events').add(event);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Tạo event "$title" thành công!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError('Lỗi khi tạo event: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo sự kiện sưu tầm'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Tiêu đề
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tiêu đề sự kiện *',
                        hintText: 'VD: Khám phá ẩm thực Sài Gòn',
                        prefixIcon: Icon(Icons.title),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập tiêu đề' : null,
                      maxLength: 100,
                    ),
                    const SizedBox(height: 16),

                    // Mô tả
                    TextFormField(
                      controller: _descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Mô tả sự kiện *',
                        hintText: 'Mô tả chi tiết về sự kiện...',
                        prefixIcon: Icon(Icons.description),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 4,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập mô tả' : null,
                    ),
                    const SizedBox(height: 16),

                    // Keywords (QUAN TRỌNG)
                    TextFormField(
                      controller: _keywordsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Từ khóa kiểm tra ảnh *',
                        hintText: 'bánh mì, phở, cà phê, dinh độc lập',
                        helperText: 'Phân cách bằng dấu phẩy. Ảnh của user phải chứa ít nhất 1 từ khóa',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập từ khóa' : null,
                    ),
                    const SizedBox(height: 16),

                    // URL icon huy hiệu
                    TextFormField(
                      controller: _badgeIconCtrl,
                      decoration: const InputDecoration(
                        labelText: 'URL icon huy hiệu (tùy chọn)',
                        hintText: 'https://example.com/badge.png',
                        prefixIcon: Icon(Icons.emoji_events),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Thời gian
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Thời gian sự kiện', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.calendar_today),
                                    label: Text('Bắt đầu\n${_start.toLocal().toString().split(' ')[0]}'),
                                    onPressed: () async {
                                      final d = await showDatePicker(
                                        context: context,
                                        initialDate: _start,
                                        firstDate: DateTime.now(),
                                        lastDate: DateTime(2100),
                                      );
                                      if (d != null) setState(() => _start = d);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.event),
                                    label: Text('Kết thúc\n${_end.toLocal().toString().split(' ')[0]}'),
                                    onPressed: () async {
                                      final d = await showDatePicker(
                                        context: context,
                                        initialDate: _end,
                                        firstDate: _start,
                                        lastDate: DateTime(2100),
                                      );
                                      if (d != null) setState(() => _end = d);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Button tạo
                    ElevatedButton.icon(
                      onPressed: _create,
                      icon: const Icon(Icons.add_circle),
                      label: const Text('Tạo sự kiện'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}