// ...existing code...
// ...existing code...
import 'dart:io';
import 'package:flutter/foundation.dart';
// ...existing code...
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:stour/services/ai_service.dart';

// ...existing code...
class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final GeminiService _gemini = GeminiService();
  final ImagePicker _picker = ImagePicker();

  File? _pickedImage;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked != null) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _pickedImage == null) return;

    setState(() {
      if (text.isNotEmpty) _messages.add({'role': 'user', 'content': text});
      if (_pickedImage != null) _messages.add({'role': 'user', 'content': '[Image]', 'image': _pickedImage!.path});
      _isLoading = true;
      _controller.clear();
    });

    try {
      String aiResponse;
      if (_pickedImage != null) {
        final question = text.isEmpty ? 'Đây là địa điểm nào?' : text;
        aiResponse = await _gemini.sendImageAndAsk(_pickedImage!, question);
      } else {
        aiResponse = await _gemini.sendMessage(text);
      }

      setState(() {
        _messages.add({'role': 'ai', 'content': aiResponse});
        _pickedImage = null;
      });
    } catch (e) {
      setState(() {
        _messages.add({'role': 'ai', 'content': '⚠️ Lỗi khi kết nối AI: $e'});
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildBubble(Map<String, dynamic> msg) {
    final isUser = msg['role'] == 'user';
    final imagePath = msg['image'] as String?;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFFDFF7E8) : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(16),
        ),
        child: imagePath != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.file(File(imagePath)),
                  if (msg['content'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(msg['content']),
                    ),
                ],
              )
            : Text(msg['content'] ?? ''),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black26,
      body: SafeArea(
        child: Center(
          child: Container(
            width: 440,
            height: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Column(
              children: [
                const Text(
                  'Wee AI',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF3B6332)),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return _buildBubble(msg);
                    },
                  ),
                ),
                if (_pickedImage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(_pickedImage!, width: 80, height: 80, fit: BoxFit.cover),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text('Ảnh đã chọn - sẵn sàng gửi')),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _pickedImage = null),
                        )
                      ],
                    ),
                  ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.photo, color: Color(0xFF3B6332)),
                      onPressed: _pickImage,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'Nhập tin nhắn...',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _isLoading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : IconButton(
                            icon: const Icon(Icons.send, color: Color(0xFF3B6332)),
                            onPressed: _send,
                          ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
// ...existing code...