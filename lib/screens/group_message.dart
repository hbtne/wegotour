// ...existing code...
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:stour/screens/call_screen.dart';
import 'package:stour/screens/group_call_screen.dart';
import 'package:stour/services/cloudinary_service.dart';

import '../assets/icons/call_video_svg.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController msgCtrl = TextEditingController();
  final ScrollController scrollCtrl = ScrollController();
  final user = FirebaseAuth.instance.currentUser;
  final ImagePicker _picker = ImagePicker();

  // speech to text
  late stt.SpeechToText _speech;
  bool _speechAvailable = false;
  bool _isListening = false;

  // flags
  bool _isUploadingImage = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();
    // Mark group as read once when entering screen
    _setReadMessage();
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Micro không khả dụng trên thiết bị này')),
          );
        }
        return;
      }
    }
    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        setState(() {
          msgCtrl.text = result.recognizedWords;
          msgCtrl.selection = TextSelection.fromPosition(
            TextPosition(offset: msgCtrl.text.length),
          );
        });
        // Nếu muốn tự động gửi khi kết thúc:
        // if (result.finalResult) _sendMessage();
      },
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 3),
      localeId: 'vi_VN',
      cancelOnError: true,
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _pickImageAndSend() async {
    // Opens bottom sheet to choose camera or gallery
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (c) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Thư viện'),
              onTap: () => Navigator.pop(c, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Máy ảnh'),
              onTap: () => Navigator.pop(c, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Huỷ'),
              onTap: () => Navigator.pop(c),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final XFile? picked = await _picker.pickImage(source: source, imageQuality: 75);
    if (picked == null) return;

    final file = File(picked.path);
    await _uploadAndSendImage(file);
  }

  // Use Cloudinary upload (same UX as ai_chatbox but uploading to Cloudinary)
  Future<void> _uploadAndSendImage(File file) async {
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng đăng nhập để gửi ảnh')));
      }
      return;
    }

    setState(() => _isUploadingImage = true);

    try {
      if (!await file.exists()) throw Exception('File không tồn tại: ${file.path}');

      final cloudinary = CloudinaryService();
      // uploadImages expects list of local paths
      final uploaded = await cloudinary.uploadImages([file.path]);

      if (uploaded.isEmpty) throw Exception('Không upload được lên Cloudinary');

      final downloadUrl = uploaded.first;
      if (kDebugMode) print('Cloudinary URL: $downloadUrl');

      // persist message in Firestore
      final msgRef = FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('messages');

      await msgRef.add({
        'senderId': user!.uid,
        'senderName': user!.displayName ?? 'Ẩn danh',
        'text': '',
        'imageUrl': downloadUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('groups').doc(widget.groupId).update({
        'lastMessage': '[Ảnh]',
        'lastTime': FieldValue.serverTimestamp(),
        'unread': true,
      });

      // scroll to bottom after a short delay
      Future.delayed(const Duration(milliseconds: 200), () {
        if (scrollCtrl.hasClients) scrollCtrl.jumpTo(scrollCtrl.position.maxScrollExtent);
      });
    } on FirebaseException catch (e) {
      if (kDebugMode) print('Firebase error while saving message: ${e.code} ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lưu tin nhắn thất bại: ${e.message ?? e.code}')));
      }
    } catch (e) {
      if (kDebugMode) print('Upload error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tải ảnh lên thất bại')));
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _setReadMessage() async {
    try {
      await FirebaseFirestore.instance.collection('groups').doc(widget.groupId).update({'unread': false});
    } catch (e) {
      if (kDebugMode) print('setReadMessage error: $e');
    }
  }

  // --- GỬI TIN NHẮN ---
  Future<void> _sendMessage() async {
    final text = msgCtrl.text.trim();
    if ((text.isEmpty && !_isUploadingImage) || user == null) return;

    setState(() => _isSending = true);

    try {
      final msgRef = FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('messages');

      await msgRef.add({
        'senderId': user!.uid,
        'senderName': user!.displayName ?? 'Ẩn danh',
        'text': text,
        'imageUrl': '', // nếu không có ảnh thì rỗng
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('groups').doc(widget.groupId).update({
        'lastMessage': text,
        'lastTime': FieldValue.serverTimestamp(),
        'unread': true,
      });

      msgCtrl.clear();

      // Cuộn xuống cuối
      Future.delayed(const Duration(milliseconds: 200), () {
        if (scrollCtrl.hasClients) {
          scrollCtrl.jumpTo(scrollCtrl.position.maxScrollExtent);
        }
      });
    } catch (e) {
      if (kDebugMode) print('Send message error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gửi tin nhắn thất bại')));
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  Widget _messageRow({required String name, required String msg, required String imageUrl}) {
    const Color greenBubble = Color(0xFF8E9F87);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFF97A989),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: greenBubble,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(imageUrl, fit: BoxFit.cover),
                    ),
                  ),
                if (msg.isNotEmpty) Text(msg, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _messageSelf(String msg, String imageUrl) {
    const Color yellowBubble = Color(0xFFFFE7A6);

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: yellowBubble,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (imageUrl.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(imageUrl, fit: BoxFit.cover),
                    ),
                  ),
                if (msg.isNotEmpty) Text(msg, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _speech.stop();
    _speech.cancel();
    msgCtrl.dispose();
    scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primary = Color(0xFF4A5C3B);
    const Color yellowBubble = Color(0xFFFFE7A6);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: primary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        "NHÓM ${widget.groupName.toUpperCase()}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                          color: primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                  IconButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context)=> GroupCallScreen(roomId: '',))),
                    icon: Icon(Icons.phone, color: primary),
                  ),
                  SizedBox(width: 10,),
                  IconButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => GroupCallScreen(roomId: ''))),
                      icon: SvgPicture.string(callVideoSVG))
                ],
              ),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('groups')
                    .doc(widget.groupId)
                    .collection('messages')
                    .orderBy('createdAt', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final messages = snapshot.data!.docs;

                  return ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index].data() as Map<String, dynamic>;
                      final isSelf = msg['senderId'] == user?.uid;
                      final text = (msg['text'] ?? '') as String;
                      final imageUrl = (msg['imageUrl'] ?? '') as String;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: isSelf
                            ? _messageSelf(text, imageUrl)
                            : _messageRow(name: msg['senderName'] ?? '', msg: text, imageUrl: imageUrl),
                      );
                    },
                  );
                },
              ),
            ),

            // --- INPUT BAR ---
            Container(
              height: 65,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: yellowBubble,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Row(
                children: [
                  // attach / image
                  _isUploadingImage
                      ? const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : IconButton(
                          icon: const Icon(Icons.attach_file, color: primary),
                          onPressed: _pickImageAndSend,
                        ),

                  // mic
                  IconButton(
                    icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? Colors.red : primary),
                    onPressed: () async {
                      if (_isListening) {
                        await _stopListening();
                      } else {
                        await _startListening();
                      }
                    },
                  ),

                  const SizedBox(width: 6),

                  Expanded(
                    child: TextField(
                      controller: msgCtrl,
                      decoration: const InputDecoration(
                        hintText: "Nhập tin nhắn...",
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),

                  _isSending
                      ? const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : IconButton(
                          icon: const Icon(Icons.send, color: primary),
                          onPressed: _sendMessage,
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}