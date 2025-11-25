import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
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

  // TODO: set your Google Vision API key here or provide via secure config.
  static const String _googleVisionApiKey = 'AIzaSyAiYethzOmZMz2H-lI6ln1-UcK16Foqh64';

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

  // Calls Google Vision REST API to analyze an image. Returns a readable summary.
  Future<String> _analyzeImageWithVision(File image) async {
    // Replace placeholder check with proper validation
    if (_googleVisionApiKey.trim().isEmpty || _googleVisionApiKey.contains('YOUR_GOOGLE_VISION_API_KEY')) {
      if (kDebugMode) print('Vision API key not set. Skipping cloud analysis.');
      return 'Google Vision API key not provided. (Set _googleVisionApiKey in code or via secure config.)';
    }

    final bytes = await image.readAsBytes();

    // Guard: limit large images to avoid 400/errors
    const maxBytes = 4 * 1024 * 1024; // 4 MB
    if (bytes.length > maxBytes) {
      if (kDebugMode) print('Image too large: ${bytes.length} bytes');
      return 'Ảnh quá lớn (${(bytes.length / 1024 / 1024).toStringAsFixed(1)} MB). Vui lòng chọn ảnh nhỏ hơn.';
    }

    final base64Image = base64Encode(bytes);
    final uri = Uri.parse('https://vision.googleapis.com/v1/images:annotate?key=$_googleVisionApiKey');

    final requestBody = {
      "requests": [
        {
          "image": {"content": base64Image},
          "features": [
            {"type": "LANDMARK_DETECTION", "maxResults": 5},
            {"type": "WEB_DETECTION", "maxResults": 5},
            {"type": "LABEL_DETECTION", "maxResults": 5},
            {"type": "LOGO_DETECTION", "maxResults": 5}
          ]
        }
      ]
    };

    final resp = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody));

    // Log full body in debug to inspect 400 details
    if (kDebugMode) {
      if (resp.statusCode != 200) {
        try {
          if (resp.body.isNotEmpty) print('Vision API response body: ${resp.body}');
        } catch (_) {}
      }
    }

    if (resp.statusCode != 200) {
      String message = 'Vision API error ${resp.statusCode}';
      try {
        final Map<String, dynamic> jb = jsonDecode(resp.body);
        if (jb['error'] != null) {
          message = jb['error']['message']?.toString() ?? resp.body.toString();
        }
      } catch (_) {}
      throw Exception('Vision API failed: $message');
    }

    final Map<String, dynamic> jsonResp = jsonDecode(resp.body);
    final annotations = jsonResp['responses']?[0] ?? {};

    final parts = <String>[];

    // Landmark
    final landmark = annotations['landmarkAnnotations'] as List<dynamic>?;
    if (landmark != null && landmark.isNotEmpty) {
      final desc = (landmark[0]['description'] ?? '').toString();
      final score = (landmark[0]['score'] ?? 0).toString();
      parts.add('Landmark detected: $desc (confidence: $score)');
    }

    // Web detection (best guess and webEntities)
    final web = annotations['webDetection'] as Map<String, dynamic>?;
    if (web != null) {
      final bestGuess = (web['bestGuessLabels'] as List<dynamic>?)?.map((b) => b['label']).whereType<String>().toList();
      if (bestGuess != null && bestGuess.isNotEmpty) {
        parts.add('Best guess: ${bestGuess.join(', ')}');
      }
      final webEntities = (web['webEntities'] as List<dynamic>?)?.map((e) => e['description']).whereType<String>().take(5).toList();
      if (webEntities != null && webEntities.isNotEmpty) {
        parts.add('Web entities: ${webEntities.join(', ')}');
      }
    }

    // Labels
    final labels = (annotations['labelAnnotations'] as List<dynamic>?)?.map((l) => '${l['description']} (${(l['score'] ?? 0).toStringAsFixed(2)})').take(5).toList();
    if (labels != null && labels.isNotEmpty) {
      parts.add('Labels: ${labels.join(', ')}');
    }

    // Logos
    final logos = (annotations['logoAnnotations'] as List<dynamic>?)?.map((l) => l['description']).whereType<String>().toList();
    if (logos != null && logos.isNotEmpty) {
      parts.add('Logos: ${logos.join(', ')}');
    }

    if (parts.isEmpty) return 'No strong visual matches found.';
    return parts.join('. ');
  }
  
  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _pickedImage == null) return;

    setState(() {
      if (text.isNotEmpty) _messages.add({'role': 'user', 'content': text});
      if (_pickedImage != null) {
        _messages.add({
          'role': 'user',
          'content': '[Image]',
          'image': _pickedImage!.path
        });
      }
      _isLoading = true;
      _controller.clear();
    });

    try {
      String aiResponse;

      if (_pickedImage != null) {
        // Analyze image with Google Vision (best-effort). Insert analysis as a system message
        String analysis;
        try {
          analysis = await _analyzeImageWithVision(_pickedImage!);
        } catch (e) {
          if (kDebugMode) print('Vision analysis failed: $e');
          analysis = 'Failed to analyze image via Vision API: $e';
        }

        // Add a system message containing the vision analysis so the model receives it in context
        _messages.add({'role': 'system', 'content': 'Image analysis: $analysis'});

        // Now call the model with the updated history (including the image user message and the system analysis)
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
          _pickedImage = null;
          _isLoading = false;
        });
        return;
      }

      // Normal text-only flow
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