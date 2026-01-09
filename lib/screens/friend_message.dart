import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:stour/assets/icons/call_video_svg.dart';
import 'package:stour/screens/call_screen.dart';
import 'package:stour/screens/ranking_screen.dart';
import 'package:stour/services/auth_service.dart';
import 'package:stour/services/cloudinary_service.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/location_message_bubble.dart';

class PersonalChatScreen extends StatefulWidget {
  final String friendId;
  final String friendName;

  const PersonalChatScreen({
    super.key,
    required this.friendId,
    required this.friendName,
  });

  @override
  State<PersonalChatScreen> createState() => _PersonalChatScreenState();
}

class _PersonalChatScreenState extends State<PersonalChatScreen> {
  final TextEditingController msgCtrl = TextEditingController();
  final ScrollController scrollCtrl = ScrollController();
  final user = FirebaseAuth.instance.currentUser;
  final ImagePicker _picker = ImagePicker();

  String? conversationId;

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
    _initConversation();
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Micro không khả dụng trên thiết bị này')));
        }
        return;
      }
    }
    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        setState(() {
          msgCtrl.text = result.recognizedWords;
          msgCtrl.selection = TextSelection.fromPosition(TextPosition(offset: msgCtrl.text.length));
        });
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

  Future<void> _initConversation() async {
    if (user == null) return;

    final userDocRef = FirebaseFirestore.instance.collection('users').doc(user!.uid);
    final friendDocRef = FirebaseFirestore.instance.collection('users').doc(widget.friendId);

    final userSnap = await userDocRef.get();
    final userData = userSnap.data() ?? {};

    List messages = userData['messages'] ?? [];
    final existing = messages.firstWhere((m) => m['friendId'] == widget.friendId, orElse: () => null);

    String convoId;
    if (existing != null) {
      convoId = existing['id'];
    } else {
      final docRef = FirebaseFirestore.instance.collection('messages').doc();
      convoId = docRef.id;

      await docRef.set({'createdAt': FieldValue.serverTimestamp()});

      await userDocRef.update({
        'messages': FieldValue.arrayUnion([
          {'id': convoId, 'friendId': widget.friendId}
        ])
      });

      await friendDocRef.update({
        'messages': FieldValue.arrayUnion([
          {'id': convoId, 'friendId': user!.uid}
        ])
      });
    }

    setState(() {
      conversationId = convoId;
    });
    _setReadMessage();
  }

  Future<void> _pickImageAndSend() async {
    final action = await showModalBottomSheet<SendAction>(
      context: context,
      builder: (c) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Thư viện'),
              onTap: () => Navigator.pop(c, SendAction.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Máy ảnh'),
              onTap: () => Navigator.pop(c, SendAction.camera),
            ),
            ListTile(
              leading: const Icon(Icons.place),
              title: const Text('Chia sẻ vị trí'),
              onTap: () => Navigator.pop(c, SendAction.location),
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

    if (action == null) return;

    if (action == SendAction.location) {
      if (conversationId == null || user == null) return;

      await Future.delayed(const Duration(milliseconds: 200));

      try {
        await sendLocationMessage(conversationId!, user!.uid);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Không gửi được vị trí')));
        }
      }
      return;
    }

    final source =
    action == SendAction.gallery ? ImageSource.gallery : ImageSource.camera;

    final XFile? picked =
    await _picker.pickImage(source: source, imageQuality: 75);

    if (picked == null) return;

    final file = File(picked.path);
    await _uploadAndSendImage(file);
  }

  Future<void> _uploadAndSendImage(File file) async {
    if (user == null || conversationId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng đăng nhập hoặc thử lại sau')));
      return;
    }

    setState(() => _isUploadingImage = true);

    try {
      if (!await file.exists()) throw Exception('File không tồn tại: ${file.path}');

      final cloudinary = CloudinaryService();
      final uploaded = await cloudinary.uploadImages([file.path]);

      if (uploaded.isEmpty) throw Exception('Không upload được lên Cloudinary');

      final downloadUrl = uploaded.first;
      if (kDebugMode) print('Cloudinary URL: $downloadUrl');

      final msgRef = FirebaseFirestore.instance.collection('messages').doc(conversationId).collection('messages');

      await msgRef.add({
        'senderId': user!.uid,
        'senderName': user!.displayName ?? 'Ẩn danh',
        'text': '',
        'imageUrl': downloadUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('messages').doc(conversationId).update({
        'lastMessage': '[Ảnh]',
        'lastTime': FieldValue.serverTimestamp(),
        'unread': true,
      });

      Future.delayed(const Duration(milliseconds: 200), () {
        if (scrollCtrl.hasClients) scrollCtrl.jumpTo(scrollCtrl.position.maxScrollExtent);
      });
    } catch (e) {
      if (kDebugMode) print('Upload error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tải ảnh lên thất bại')));
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _setReadMessage() async {
    if (conversationId == null) return;
    try {
      await FirebaseFirestore.instance.collection('messages').doc(conversationId).update({'unread': false});
    } catch (e) {
      if (kDebugMode) print('setReadMessage error: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = msgCtrl.text.trim();
    if ((text.isEmpty && !_isUploadingImage) || user == null || conversationId == null) return;

    setState(() => _isSending = true);

    try {
      final msgRef = FirebaseFirestore.instance.collection('messages').doc(conversationId).collection('messages');

      await msgRef.add({
        'senderId': user!.uid,
        'senderName': user!.displayName ?? 'Ẩn danh',
        'avatarUrl': AuthService.getCurrentUserAvatar(),
        'text': text,
        'imageUrl': '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('messages').doc(conversationId).update({
        'lastMessage': text,
        'lastTime': FieldValue.serverTimestamp(),
        'unread': true,
      });

      msgCtrl.clear();

      Future.delayed(const Duration(milliseconds: 200), () {
        if (scrollCtrl.hasClients) scrollCtrl.jumpTo(scrollCtrl.position.maxScrollExtent);
      });
    } catch (e) {
      if (kDebugMode) print('Send message error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gửi tin nhắn thất bại')));
    } finally {
      setState(() => _isSending = false);
    }
  }

  Widget _messageRow(Map<String, dynamic> msg) {
    final Color greenBubble = Color(0xFF8E9F87);
    final avatarUrl = (msg['avatarUrl'] ?? '') as String;

    if (msg['type'] == 'location') {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Colors.transparent,
            backgroundImage: avatarUrl != ""
                ? NetworkImage(avatarUrl)
                : const AssetImage(
                'assets/default_avatar.png') as ImageProvider,
          ),
          LocationMessageBubble(
            lat: msg['lat'],
            lng: msg['lng'],
          )
        ],
      );
    }

    final text = (msg['text'] ?? '') as String;
    final imageUrl = (msg['imageUrl'] ?? '') as String;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: Colors.transparent,
          backgroundImage: avatarUrl != ""
              ? NetworkImage(avatarUrl)
              : const AssetImage('assets/default_avatar.png') as ImageProvider,
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
                if (msg.isNotEmpty) Text(text, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _messageSelf(Map<String, dynamic> msg) {
    const Color yellowBubble = Color(0xFFFFE7A6);

    if (msg['type'] == 'location') {
      return GestureDetector(
        onTap: () {
          final url =
              "https://www.google.com/maps/search/?api=1&query=$msg['lat'],$msg['lng']";
          launchUrl(Uri.parse(url));
        },
        child: LocationMessageBubble(
          lat: msg['lat'],
          lng: msg['lng'],),
      );
    }

    final text = (msg['text'] ?? '') as String;
    final imageUrl = (msg['imageUrl'] ?? '') as String;

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
                if (msg.isNotEmpty) Text(text, style: const TextStyle(fontSize: 16)),
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

  void _onCall(bool audioOnly) async {
    final callDoc = FirebaseFirestore.instance.collection('calls').doc();
    final callId = callDoc.id;

    await callDoc.set({
      "callerId": AuthService.getCurrentUserId(),
      "callerName": AuthService.getCurrentUserName(),
      "calleeId": widget.friendId,
      "calleeName": widget.friendName,
      "participants": [
        widget.friendId,
      ],
      "status": "ringing",
      "mode": audioOnly ? "audio" : "video",
      "createdAt": FieldValue.serverTimestamp()
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          callId: callId,
          audioOnly: audioOnly,
          isCaller: true,
          calleeName: widget.friendName,
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, String friendName, Color primary) {
    return AppBar(
      backgroundColor: Colors.white,
      centerTitle: true,
      title: Text(
        friendName,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: primary,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: primary),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
            onPressed: () => _onCall(true),
            icon: Icon(Icons.call, color: primary,)),
        IconButton(
            onPressed: () => _onCall(false),
            icon: Icon(Icons.videocam, color: primary))
      ],
    );
  }

  Future<Position> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception("Location service disabled");
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception("Location permission permanently denied");
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> sendLocationMessage(String chatId, String senderId,) async {
    final position = await getCurrentLocation();

    await FirebaseFirestore.instance
        .collection('messages')
        .doc(chatId)
        .collection('messages')
        .add({
      'senderId': senderId,
      'avatarUrl': AuthService.getCurrentUserAvatar(),
      'type': 'location',
      'lat': position.latitude,
      'lng': position.longitude,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color primary = Color(0xFF4A5C3B);
    const Color yellowBubble = Color(0xFFFFE7A6);

    if (conversationId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(context, widget.friendName, primary),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('messages')
                    .doc(conversationId)
                    .collection('messages')
                    .orderBy('createdAt', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final messages = snapshot.data!.docs;
                  return ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index].data() as Map<String, dynamic>;
                      final isSelf = msg['senderId'] == user?.uid;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: isSelf ? _messageSelf(msg) : _messageRow(msg),
                      );
                    },
                  );
                },
              ),
            ),
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
                  _isUploadingImage
                      ? const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : IconButton(
                          icon: const Icon(Icons.attach_file, color: primary),
                          onPressed: _pickImageAndSend,
                        ),
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
                      decoration: const InputDecoration(hintText: "Nhập tin nhắn...", border: InputBorder.none),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  _isSending
                      ? const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : IconButton(icon: const Icon(Icons.send, color: primary), onPressed: _sendMessage),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum SendAction {
  gallery,
  camera,
  location,
}
