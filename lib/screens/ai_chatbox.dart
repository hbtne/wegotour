import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:stour/services/ai_service.dart';
import 'package:stour/screens/details.dart';
import 'package:stour/util/places.dart';

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

  // Speech to text
  late stt.SpeechToText _speech;
  bool _speechAvailable = false;
  bool _isListening = false;
  double _soundLevel = 0.0;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          if (kDebugMode) print('Speech status: $status');
          if (status == 'notListening' || status == 'done') {
            setState(() => _isListening = false);
          }
        },
        onError: (error) {
          if (kDebugMode) print('Speech error: $error');
          setState(() => _isListening = false);
        },
      );
      setState(() {});
    } catch (e) {
      if (kDebugMode) print('Init speech failed: $e');
      setState(() => _speechAvailable = false);
    }
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) {
      await _initSpeech();
      if (!_speechAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Micro không khả dụng trên thiết bị này')),
        );
        return;
      }
    }
    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        setState(() {
          _controller.text = result.recognizedWords;
          _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: _controller.text.length));
        });
      },
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 3),
      localeId: 'vi_VN',
      onSoundLevelChange: (level) {
        setState(() => _soundLevel = level);
      },
      cancelOnError: true,
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _pickImage() async {
    final XFile? picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked != null) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _pickedImage == null) return;

    setState(() {
      if (text.isNotEmpty) _messages.add({'role': 'user', 'content': text});
      if (_pickedImage != null)
        _messages.add({
          'role': 'user',
          'content': '[Image]',
          'image': _pickedImage!.path
        });
      _isLoading = true;
      _controller.clear();
    });

    try {
      String aiResponse;

      if (_pickedImage != null) {
        final demoPlace = Place(
          id: 'dinh_doc_lap',
          name: 'Dinh Độc Lập',
          img:
              'https://res.cloudinary.com/dibmnb2rp/image/upload/v1762172020/posts/sr6erbwwchoent8wi3zy.jpg',
          address: '135 Nam Kỳ Khởi Nghĩa',
          price: 60000.0,
          openTime: 8,
          closeTime: 17,
          history:
              'Dinh Độc Lập là một tòa dinh thự tại Thành phố Hồ Chí Minh, từng là nơi ở và làm việc của Tổng thống Việt Nam Cộng hòa trước Sự kiện 30 tháng 4 năm 1975. Hiện nay, Dinh Độc Lập đã được Chính phủ Việt Nam xếp hạng là di tích quốc gia đặc biệt. Cơ quan quản lý di tích văn hoá Dinh Độc Lập có tên là Hội trường Thống Nhất thuộc Văn phòng Chính phủ.',
          rating: '4,6',
          duration: 60,
          district: 'Quận 1',
          city: 'TP.HCM',
          isAccepted: true,
        );
        final canned =
            'Đây là Dinh Độc Lập (Independence Palace) — một biểu tượng lịch sử của TP. Hồ Chí Minh. '
            'Dinh được xây dựng từ thời thuộc Pháp, là nơi diễn ra nhiều sự kiện lịch sử quan trọng.';

        setState(() {
          _messages.add({'role': 'ai', 'content': canned, 'place': demoPlace});
          _pickedImage = null;
          _isLoading = false;
        });
        return;
      }

      aiResponse = await _gemini.sendMessageWithHistory(
        _messages
            .map((m) => {
                  'role': m['role'] as String,
                  'content': (m['content'] ?? '').toString(),
                })
            .toList(),
      );
      setState(() {
        _messages.add({'role': 'ai', 'content': aiResponse});
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
    final placeObj = msg['place'] as Place?;
    final content = (msg['content'] ?? '').toString();

    // Build a Markdown style sheet based on theme so it looks natural
    final mdStyle = MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: TextStyle(
        color: Colors.black87,
        fontSize: 14,
        height: 1.4,
      ),
      // Customize strong/bold color if needed:
      strong: const TextStyle(fontWeight: FontWeight.bold),
    );

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFFDFF7E8) : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imagePath != null) ...[
              Image.file(File(imagePath)),
              if (content.isNotEmpty) const SizedBox(height: 8),
            ],
            if (content.isNotEmpty)
              // Use MarkdownBody so **bold** and *italic* render correctly
              MarkdownBody(
                data: content,
                styleSheet: mdStyle,
                selectable: false,
                // Optionally constrain or handle onTapLink if you want links clickable
              ),
            if (placeObj != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DetailScreen(placeToDisplay: placeObj),
                    ),
                  );
                },
                child: const Text('Xem chi tiết',
                    style: TextStyle(color: Color(0xFF3B6332))),
              )
            ]
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _speech.stop();
    _speech.cancel();
    _controller.dispose();
    super.dispose();
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
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3B6332)),
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
                          child: Image.file(_pickedImage!,
                              width: 80, height: 80, fit: BoxFit.cover),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                            child: Text('Ảnh đã chọn - sẵn sàng gửi')),
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
                    IconButton(
                      icon: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: _isListening ? Colors.red : const Color(0xFF3B6332),
                      ),
                      onPressed: () async {
                        if (_isListening) {
                          await _stopListening();
                        } else {
                          await _startListening();
                        }
                      },
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'Nhập tin nhắn...',
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _isLoading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : IconButton(
                            icon: const Icon(Icons.send,
                                color: Color(0xFF3B6332)),
                            onPressed: _send,
                          ),
                  ],
                ),
                if (_isListening)
                  Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: LinearProgressIndicator(
                      value: (_soundLevel / 10).clamp(0.0, 1.0),
                      backgroundColor: Colors.grey[200],
                      color: Colors.redAccent,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}