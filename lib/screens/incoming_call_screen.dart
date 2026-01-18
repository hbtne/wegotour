import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/call_service.dart';
import 'call_screen.dart';
import 'group_call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callId;
  final String callerName;
  final String callerAvatar;
  final String callType;
  final List<String> participants;
  final VoidCallback? onFinish;
  final bool isGroup;

  const IncomingCallScreen({
    required this.callId,
    required this.callerName,
    required this.callerAvatar,
    required this.callType,
    required this.participants,
    this.onFinish,
    super.key, required this.isGroup,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  final _db = FirebaseFirestore.instance;
  bool _isProcessing = false;
  final CallService callService = CallService();
  StreamSubscription<DocumentSnapshot>? _callSub;

  Future<void> _accept({required bool audioOnly}) async {
    try {
      widget.isGroup ?
      await _db.collection('group_calls').doc(widget.callId).update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
        'acceptedMode': audioOnly ? 'audio' : 'video',
      })
      : await _db.collection('calls').doc(widget.callId).update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
        'acceptedMode': audioOnly ? 'audio' : 'video',
      });
    } catch (e) {print("Bug incomming: $e");}

    Navigator.of(context).pop();
    widget.onFinish?.call();

    if (widget.isGroup) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => GroupCallScreen(groupCallId: widget.callId, audioOnly: audioOnly, isCaller: false, participants: widget.participants, title: widget.callerName,),
      ));
    } else {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CallScreen(callId: widget.callId, audioOnly: audioOnly, isCaller: false, isConnected: true, calleeName: widget.callerName,),
      ));
    }
  }

  @override
  void initState() {
    super.initState();
    _listenCallStatus();
  }

  void _listenCallStatus() {
    final collection = widget.isGroup ? 'group_calls' : 'calls';

    _callSub = FirebaseFirestore.instance
        .collection(collection)
        .doc(widget.callId)
        .snapshots()
        .listen((doc) {
      if (!doc.exists) return;

      final status = doc.data()?['status'];

      // Caller hủy / kết thúc trước khi callee bắt máy
      if (status == 'cancelled' || status == 'ended') {
        if (mounted) {
          Navigator.of(context).pop(); // đóng dialog
          widget.onFinish?.call();     // tắt ringtone, clear _shown
        }
      }
    });
  }

  @override
  void dispose() {
    _callSub?.cancel();
    super.dispose();
  }

  Future<void> _decline() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      await _db.collection('calls').doc(widget.callId).update({
        'status': 'declined',
        'declinedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {}

    Navigator.of(context).pop();
    widget.onFinish?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isGroup = widget.callType == 'group';
    const Color primary = Color(0xFF4A5C3B);
    print("incomming screen opened");
    return WillPopScope(
      onWillPop: () async => false,
      child: Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Container(width: double.infinity, height: double.infinity, color: Colors.black87),
            SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: widget.callerAvatar.isNotEmpty ? NetworkImage(widget.callerAvatar) : null,
                    child: widget.callerAvatar.isEmpty ? Icon(Icons.person, size: 60, color: Colors.white70) : null,
                  ),
                  SizedBox(height: 20),
                  Text(widget.callerName, style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(
                    isGroup ? 'Cuộc gọi nhóm' : (widget.callType == 'audio' ? 'Gọi thoại' : 'Gọi video'),
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          FloatingActionButton(
                            heroTag: 'decline_${widget.callId}',
                            onPressed: _decline,
                            child: Icon(Icons.call_end, color: Colors.red),
                          ),
                        ],
                      ),
                      widget.callType == 'audio' ? _acceptByAudio() : _acceptByVideo()
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _acceptByAudio() => Stack(
    children: [
      Column(
        children: [
          FloatingActionButton(
            heroTag: 'accept_audio_${widget.callId}',
            onPressed: () => _accept(audioOnly: true),
            child: Icon(Icons.call, color: Colors.green),
          ),
        ],
      ),
    ],
  );

  Widget _acceptByVideo() => Stack(
    children: [
      Column(
        children: [
          FloatingActionButton(
            heroTag: 'accept_video_${widget.callId}',
            onPressed: () => _accept(audioOnly: false),
            child: Icon(Icons.videocam, color: Colors.green),
          ),
        ],
      ),
    ],
  );
}
