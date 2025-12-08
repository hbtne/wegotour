import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EventSubmissionWidget extends StatefulWidget {
  final String eventId;
  const EventSubmissionWidget({required this.eventId, super.key});

  @override
  _EventSubmissionWidgetState createState() => _EventSubmissionWidgetState();
}

class _EventSubmissionWidgetState extends State<EventSubmissionWidget> {
  XFile? _picked;
  final _captionController = TextEditingController();
  bool _loading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    setState(() { _picked = picked; });
  }

  Future<void> _submit() async {
    if (_picked == null) return;
    setState(() { _loading = true; });
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = FirebaseStorage.instance.ref().child('submissions/${widget.eventId}/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(File(_picked!.path));
    final url = await ref.getDownloadURL();
    await FirebaseFirestore.instance.collection('eventSubmissions').doc().set({
      'eventId': widget.eventId,
      'userId': uid,
      'imageUrl': url,
      'caption': _captionController.text,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp()
    });
    setState(() { _loading = false; _picked = null; _captionController.clear(); });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã gửi bài dự thi.')));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_picked != null) Image.file(File(_picked!.path), height: 200),
        Row(
          children: [
            ElevatedButton.icon(onPressed: _pickImage, icon: Icon(Icons.camera_alt), label: Text('Chụp/Chọn')),
            SizedBox(width: 8),
            ElevatedButton(onPressed: _submit, child: _loading ? CircularProgressIndicator() : Text('Gửi'))
          ],
        ),
        TextField(controller: _captionController, decoration: InputDecoration(labelText: 'Mô tả')),
      ],
    );
  }
}